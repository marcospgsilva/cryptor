defmodule Cryptor.Trader do
  @moduledoc """
   Trader
  """

  alias Cryptor.{
    Analysis,
    AmountControl,
    Orders,
    Orders.PendingOrdersAgent,
    Orders.Order,
    Requests,
    Trader.TradeServer,
    Utils
  }

  def analyze_transaction(current_price, %Order{price: price, coin: coin} = order) do
    %Analysis{sell_percentage_limit: sell_percentage_limit} =
      :sys.get_state(String.to_existing_atom(coin <> "Server"))

    if current_price >= price * sell_percentage_limit,
      do: place_order(:sell, current_price, order)
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

  def validate_pending_sell_order(:sell = method, currency) do
    case PendingOrdersAgent.get_pending_orders_list()
         |> Enum.find(fn %{type: type, coin: coin} ->
           type == to_string(method) && coin == currency
         end) do
      nil ->
        :ok

      _ ->
        :error
    end
  end

  def validate_pending_sell_order(_, _), do: :ok

  def place_order(:sell, _, %Order{quantity: 0.0}), do: nil

  def place_order(method, newer_price, %Order{coin: currency} = order) do
    quantity = AmountControl.get_quantity(method, newer_price, order)

    method
    |> validate_pending_sell_order(currency)
    |> validate_available_money(
      method,
      quantity,
      newer_price
    )
    |> place_order(quantity, method, "BRL#{currency}", newer_price)
    |> process_order(order)
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

  def validate_available_money(:error, _, _, _), do: {:error, :pending_sell_order}

  def validate_available_money(:ok, :sell, _, _), do: :ok

  def validate_available_money(:ok, :buy, quantity, newer_price) do
    {:ok, available_amount} =
      get_account_info_data()
      |> Utils.get_available_amount("brl")

    order_value = quantity * newer_price

    if available_amount > order_value,
      do: :ok,
      else: {:error, :no_enough_money}
  end

  def process_order(
        {:ok, %{"response_data" => %{"order" => %{"order_type" => 2} = new_order}}},
        order
      ) do
    add_to_pending_orders(
      Utils.build_valid_order(new_order)
      |> Map.put(:buy_order_id, order.order_id),
      order
    )
  end

  def process_order({:ok, %{"response_data" => %{"order" => new_order}}}, order) do
    add_to_pending_orders(
      Utils.build_valid_order(new_order),
      order
    )
  end

  def process_order({:ok, _}, _), do: {:error, :unexpected_response}

  def process_order({:error, _} = error, _), do: error

  def add_to_pending_orders(pending_order, _order),
    do: PendingOrdersAgent.add_to_pending_orders_list(pending_order)

  def create_and_add_order(order),
    do:
      Orders.create_order(order)
      |> TradeServer.add_order()

  def remove_and_update_order(order) do
    buy_order = Orders.get_order(order.buy_order_id)
    TradeServer.remove_order(buy_order)
    Orders.update_order(buy_order, %{finished: true})

    order
    |> Map.pop(:buy_order_id)
    |> elem(1)
    |> Map.put(:finished, true)
    |> Orders.create_order()
  end

  def delete_order(id) do
    order = Orders.get_order(id)
    TradeServer.remove_order(order)
    Orders.update_order(order, %{finished: true})
  end

  def get_account_info_data do
    state = TradeServer.get_state()
    state[:account_info]
  end
end
