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

  @currencies ["BTC", "LTC", "XRP", "ETH", "USDC", "BCH"]

  def get_currencies, do: @currencies

  def analyze_transaction(current_price, %Order{price: price, coin: currency} = order, user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id, currency)

    %BotServer.State{bot: bot = %Bot{}} = BotServer.get_state(pids[:bot_pid])

    if current_price >= price * bot.sell_percentage_limit,
      do: place_order(:sell, current_price, order, user_id)
  end

  def get_currency_price(coin) do
    with {:ok, %{"ticker" => %{"last" => last}}} <- Requests.request(:get, "#{coin}/ticker/"),
         do: {:ok, String.to_float(last)}
  end

  def get_account_info do
    with {:ok, response} <- Requests.request(:post, %{tapi_method: "get_account_info"}),
         do: response
  end

  def get_order_data(order) do
    with {:ok, %{"response_data" => %{"order" => %{"status" => order_status, "fee" => fee}}}} <-
           Requests.request(:post, %{
             tapi_method: "get_order",
             coin_pair: "BRL" <> order.coin,
             order_id: order.order_id
           }) do
      mapped_statuses = Order.mapped_order_statuses()
      %{status: Map.get(mapped_statuses, to_string(order_status)), fee: fee}
    end
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
    |> place_order(quantity, method, "BRL#{currency}", newer_price)
    |> process_order(order, user_id)
  end

  def place_order({:error, _} = error, _, _, _, _),
    do: error

  def place_order(:ok, quantity, method, coin_pair, newer_price) do
    Requests.request(:post, %{
      tapi_method: Utils.get_tapi_method(method),
      coin_pair: coin_pair,
      quantity: :erlang.float_to_binary(quantity, [:compact, {:decimals, 8}]),
      limit_price: newer_price,
      async: true
    })
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

    {:ok, available_amount} =
      pids[:analysis_pid]
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
  end

  def create_and_add_order(order) do
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)
    order = Orders.create_order(order)

    add_order_to_analysis_server(pids[:bot_pid], order)
    OrdersAgent.add_to_order_list(pids[:orders_pid], order)
  end

  def remove_and_update_order(order) do
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)
    buy_order = Orders.get_order(order.buy_order_id)

    remove_order_from_analysis_server(pids[:bot_pid], order)
    OrdersAgent.remove_from_order_list(pids[:orders_pid], order)
    Orders.update_order(buy_order, %{finished: true})

    order
    |> Map.pop(:buy_order_id)
    |> elem(1)
    |> Map.put(:finished, true)
    |> Orders.create_order()
  end

  def delete_order(id) do
    order = Orders.get_order(id)
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)

    remove_order_from_analysis_server(pids[:bot_pid], order)
    OrdersAgent.remove_from_order_list(pids[:orders_pid], order)
    Orders.update_order(order, %{finished: true})
  end

  def get_account_info_data(analysis_pid) do
    state = Analysis.get_state(analysis_pid)
    state[:account_info]
  end

  def process_pending_order(%{buy_order_id: _buy_order_id} = order),
    do: remove_and_update_order(order)

  def process_pending_order(order) do
    %{fee: fee} = get_order_data(order)
    updated_order = %{order | fee: fee}
    create_and_add_order(updated_order)
  end

  def add_order_to_analysis_server(analysis_pid, %Order{} = order) when order.coin in @currencies,
    do: GenServer.cast(analysis_pid, {:add_order, order})

  def add_order_to_analysis_server(_, _), do: :ok

  def remove_order_from_analysis_server(analysis_pid, %Order{} = order),
    do: GenServer.cast(analysis_pid, {:remove_order, order})
end
