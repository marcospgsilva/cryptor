defmodule Cryptor.Trader do
  @moduledoc """
   Trader
  """

  alias Cryptor.{
    Analysis,
    BotServer,
    BotServer.State,
    AmountControl,
    Bots.Bot,
    Orders,
    Orders.PendingOrdersAgent,
    Orders.OrdersAgent,
    ProcessRegistry,
    Orders.Order,
    Requests,
    Utils
  }

  @currencies ["BTC", "LTC", "XRP", "ETH", "USDC", "BCH", "ADA"]

  def get_currencies, do: @currencies

  def analyze_transaction(current_price, %Order{price: price, coin: currency} = order, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id, currency)
    %State{bot: bot = %Bot{}} = BotServer.get_state(pids[:bot_pid])

    if current_price >= price * bot.sell_percentage_limit,
      do: place_order(:sell, current_price, order, user_id)
  end

  def get_currency_price(coin) do
    with {:ok, %{"ticker" => %{"last" => last}}} <-
           Requests.request(:get, "#{coin}/ticker/"),
         do: {:ok, String.to_float(last)}
  end

  def get_account_info(user_id) do
    with {:ok, response} <-
           Requests.request(:post, %{tapi_method: "get_account_info"}, user_id),
         do: response
  end

  def get_order_data(order, user_id) do
    with {:ok, %{"response_data" => %{"order" => %{"status" => order_status, "fee" => fee}}}} <-
           Requests.request(
             :post,
             %{
               tapi_method: "get_order",
               coin_pair: "BRL" <> order.coin,
               order_id: order.order_id
             },
             user_id
           ) do
      mapped_statuses = Order.mapped_order_statuses()
      %{status: Map.get(mapped_statuses, to_string(order_status)), fee: fee}
    end
  end

  def set_order_status_canceled(order, user_id) do
    Requests.request(
      :post,
      %{
        tapi_method: "cancel_order",
        coin_pair: "BRL" <> order.coin,
        order_id: order.order_id
      },
      user_id
    )
  end

  def place_order(:sell, _, %Order{quantity: 0.0}, _user_id), do: nil

  def place_order(method, newer_price, %Order{coin: currency} = order, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id, currency)
    %State{bot: bot} = BotServer.get_state(pids[:bot_pid])

    quantity = AmountControl.get_quantity(method, newer_price, order, bot)

    method
    |> validate_pending_sell_order(currency, user_id)
    |> validate_available_money(
      method,
      quantity,
      newer_price,
      user_id
    )
    |> place_order(quantity, method, "BRL#{currency}", newer_price, user_id)
    |> process_order(order, user_id)
  end

  def place_order({:error, _} = error, _, _, _, _, _),
    do: error

  def place_order(:ok, quantity, method, coin_pair, newer_price, user_id) do
    Requests.request(
      :post,
      %{
        tapi_method: Utils.get_tapi_method(method),
        coin_pair: coin_pair,
        quantity: :erlang.float_to_binary(quantity, [:compact, {:decimals, 8}]),
        limit_price: newer_price,
        async: true
      },
      user_id
    )
  end

  def validate_pending_sell_order(:sell = method, currency, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id)

    case PendingOrdersAgent.get_pending_orders_list(pids[:pending_orders_pid])
         |> Enum.find(fn %{type: type, coin: coin} ->
           type == Utils.get_order_type(method) && coin == currency
         end) do
      nil -> :ok
      _ -> :error
    end
  end

  def validate_pending_sell_order(_, _, _), do: :ok

  def validate_available_money(:error, _, _, _, _), do: {:error, :pending_sell_order}

  def validate_available_money(:ok, :sell, _, _, _), do: :ok

  def validate_available_money(:ok, :buy, quantity, newer_price, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    analysis_pid = pids[:analysis_pid]

    {:ok, available_amount} =
      analysis_pid
      |> get_account_info_data()
      |> Utils.get_available_amount("brl")

    order_value = quantity * newer_price

    if available_amount > order_value,
      do: :ok,
      else: {:error, :no_enough_money}
  end

  def process_order(
        {:ok, %{"response_data" => %{"order" => %{"order_type" => 2} = new_order}}},
        order,
        user_id
      ) do
    add_to_pending_orders(
      Utils.build_valid_order(new_order)
      |> Map.put(:buy_order_id, order.order_id),
      order,
      user_id
    )
  end

  def process_order({:ok, %{"response_data" => %{"order" => new_order}}}, order, user_id) do
    add_to_pending_orders(
      Utils.build_valid_order(new_order),
      order,
      user_id
    )
  end

  def process_order({:ok, _}, _, _), do: {:error, :unexpected_response}

  def process_order({:error, _} = error, _, _), do: error

  def add_to_pending_orders(pending_order, _order, user_id) do
    pending_order = pending_order |> Map.put(:user_id, user_id)
    pids = ProcessRegistry.get_servers_registry(user_id)

    PendingOrdersAgent.add_to_pending_orders_list(pids[:pending_orders_pid], pending_order)
    Orders.create_order(pending_order)
  end

  def create_and_add_order(order) do
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)
    order = Orders.get_order(order.order_id, order.user_id)
    {:ok, order} = Orders.update_order(order, %{filled: true})

    OrdersAgent.add_to_order_list(pids[:orders_pid], order)
    update_bot_server_orders(pids[:bot_pid])
  end

  def remove_and_update_order(order) do
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)
    buy_order = Orders.get_order(order.buy_order_id, order.user_id)

    OrdersAgent.remove_from_order_list(pids[:orders_pid], order)
    update_bot_server_orders(pids[:bot_pid])
    Orders.update_order(buy_order, %{finished: true})

    Orders.update_order(order, %{finished: true, filled: true})
  end

  def delete_order(id, user_id) do
    order = Orders.get_order(id, user_id)
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)

    OrdersAgent.remove_from_order_list(pids[:orders_pid], order)
    update_bot_server_orders(pids[:bot_pid])
    Orders.update_order(order, %{finished: true})
  end

  def remove_order_from_pending_list(id, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id)
    order = Orders.get_order(id, user_id)

    case set_order_status_canceled(order, user_id) do
      {:ok, _} ->
        PendingOrdersAgent.remove_from_pending_orders_list(pids[:pending_orders_pid], order)
        Orders.update_order(order, %{finished: true, filled: true})

      _ ->
        nil
    end
  end

  def get_account_info_data(analysis_pid) do
    state = Analysis.get_state(analysis_pid)
    state[:account_info]
  end

  def process_pending_order(%{buy_order_id: nil} = order, user_id) do
    %{fee: fee} = get_order_data(order, user_id)
    updated_order = %{order | fee: fee}
    create_and_add_order(updated_order)
  end

  def process_pending_order(order, _),
    do: remove_and_update_order(order)

  def update_bot_server_orders(bot_pid),
    do: GenServer.call(bot_pid, :update_orders)
end
