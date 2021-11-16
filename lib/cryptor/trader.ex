defmodule Cryptor.Trader do
  @moduledoc """
   Trader
  """

  alias Cryptor.{
    Analysis,
    AmountControl,
    Orders,
    Orders.PendingOrdersAgent,
    Orders.OrdersAgent,
    ProcessRegistry,
    Orders.Order,
    Requests,
    Utils
  }

  @currencies ["BTC", "LTC", "XRP", "ETH", "USDT", "ADA"]

  def get_currencies, do: @currencies

  def analyze_transaction(0.0, _, _, _), do: nil

  def analyze_transaction(
        current_price,
        %Order{price: price} = order,
        user_id,
        bot
      ) do
    if current_price >= price * bot.sell_percentage_limit,
      do: place_order(:sell, current_price, order, user_id, bot)
  end

  def get_account_info(user_id) do
    with {:ok, %{"balances" => balances}} <- Requests.request(:get, "/account", %{}, user_id) do
      balances
    end
  end

  def get_order_data(order, user_id) do
    with {:ok, %{"status" => order_status}} <-
           Requests.request(
             :get,
             "/order",
             %{
               symbol: order.coin <> "BRL",
               orderId: order.order_id
             },
             user_id
           ) do
      mapped_statuses = Order.mapped_order_statuses()
      %{status: Map.get(mapped_statuses, to_string(order_status))}
    end
  end

  def set_order_status_canceled(order, user_id) do
    Requests.request(
      :delete,
      "/order",
      %{
        symbol: order.coin <> "BRL",
        orderId: order.order_id
      },
      user_id
    )
  end

  def place_order(:sell, _, %Order{quantity: 0.0}, _user_id, _bot), do: nil

  def place_order(method, newer_price, %Order{coin: currency} = order, user_id, bot) do
    quantity = AmountControl.get_quantity(method, newer_price, order, bot.buy_amount)

    method
    |> validate_pending_sell_order(currency, user_id)
    |> validate_available_money(
      method,
      quantity,
      newer_price,
      user_id
    )
    |> place_order(quantity, method, "#{currency}BRL", newer_price, user_id)
    |> process_order(order, user_id)
  end

  def place_order({:error, _} = error, _, _, _, _, _),
    do: error

  def place_order(:ok, quantity, method, coin_pair, newer_price, user_id) do
    Requests.request(
      :post,
      "/order",
      %{
        side: Utils.get_tapi_method(method),
        symbol: coin_pair,
        quantity: Utils.format_float_with_decimals(quantity),
        price: newer_price,
        type: "LIMIT",
        newOrderRespType: "FULL",
        timeInForce: "GTC"
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
      |> Utils.get_available_amount("BRL")

    order_value = quantity * newer_price

    if available_amount > order_value,
      do: :ok,
      else: {:error, :no_enough_money}
  end

  def process_order(
        {:ok, %{"side" => "SELL"} = new_order},
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

  def process_order({:ok, new_order}, order, user_id) do
    add_to_pending_orders(
      Utils.build_valid_order(new_order),
      order,
      user_id
    )
  end

  def process_order({:error, _} = error, _, _), do: error

  def add_to_pending_orders(pending_order, _order, user_id) do
    pending_order = pending_order |> Map.put(:user_id, user_id)
    pids = ProcessRegistry.get_servers_registry(user_id)

    pending_order = Orders.create_order(pending_order |> Map.from_struct())
    PendingOrdersAgent.add_to_pending_orders_list(pids[:pending_orders_pid], pending_order)
  end

  def create_and_add_order(order) do
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)
    loaded_order = Orders.get_order(order.order_id, order.user_id)
    {:ok, order} = Orders.update_order(loaded_order, %{filled: true, fee: order.fee})

    OrdersAgent.add_to_order_list(pids[:orders_pid], order)
  end

  def remove_and_update_order(order) do
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)
    buy_order = Orders.get_order(order.buy_order_id, order.user_id)
    order = Orders.get_order(order.order_id, order.user_id)

    OrdersAgent.remove_from_order_list(pids[:orders_pid], buy_order)
    Orders.update_order(buy_order, %{finished: true})

    {:ok, order} = Orders.update_order(order, %{finished: true, filled: true})

    Process.send(pids[:bot_pid], {:update_latest_sell_order, order}, [])
  end

  def delete_order(id, user_id) do
    order = Orders.get_order(id, user_id)
    pids = ProcessRegistry.get_servers_registry(order.user_id, order.coin)

    OrdersAgent.remove_from_order_list(pids[:orders_pid], order)
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

  def process_pending_order(%{buy_order_id: nil} = order, _user_id) do
    create_and_add_order(order)
  end

  def process_pending_order(order, _),
    do: remove_and_update_order(order)
end
