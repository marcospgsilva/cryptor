defmodule Cryptor.Trader do
  @moduledoc """
   Trader
  """

  alias Cryptor.Requests
  alias Cryptor.Trader.Server
  alias Cryptor.Trader.AmountControl
  alias Cryptor.Trader.PendingOrdersAgent
  alias Cryptor.Order
  alias Cryptor.Utils
  alias Cryptor.Analysis

  @filled_order_status [4, 3]

  def analyze_transaction(current_price, %Order{price: price, coin: coin} = order) do
    %Analysis{
      sell_percentage_limit: sell_percentage_limit,
      buy_percentage_limit: buy_percentage_limit
    } = :sys.get_state(String.to_existing_atom(coin <> "Server"))

    cond do
      current_price >= price * sell_percentage_limit ->
        place_order(:sell, current_price, order)

      current_price <= price * buy_percentage_limit ->
        place_order(:buy, current_price, order)

      true ->
        nil
    end
  end

  def get_currency_price(coin) do
    case Requests.request(:get, "#{coin}/ticker/") do
      {:ok, %{"ticker" => %{"last" => last}}} ->
        String.to_float(last)

      _ ->
        nil
    end
  end

  def get_account_info do
    case Requests.request(:post, %{tapi_method: "get_account_info"}) do
      {:ok, response} -> response
      _ -> get_account_info()
    end
  end

  def get_order_status(order) do
    with {:ok, %{"response_data" => %{"order" => %{"status" => order_status}}}} <-
           Requests.request(:post, %{
             tapi_method: "get_order",
             coin_pair: "BRL" <> order.coin,
             order_id: order.order_id
           }) do
      if(order_status in @filled_order_status, do: :done, else: nil)
    end
  end

  def place_order(:sell, _, %Order{quantity: 0.0}), do: nil

  def place_order(method, newer_price, %Order{coin: coin} = order) do
    quantity = AmountControl.get_quantity(method, newer_price, order)

    Utils.get_open_order(coin)
    |> validate_available_money(
      method,
      quantity,
      newer_price
    )
    |> place_order(quantity, method, "BRL#{coin}", newer_price)
    |> process_order(order)
  end

  def validate_available_money(nil, _, _, _), do: nil

  def validate_available_money(_, :sell, _, _), do: :ok

  def validate_available_money(:ok, :buy, quantity, newer_price) do
    available_brl =
      get_account_info_data()
      |> Utils.get_available_value("brl")

    order_value = quantity * newer_price

    case available_brl > order_value do
      true -> :ok
      _ -> nil
    end
  end

  def place_order(nil, _, _, _, _),
    do: nil

  def place_order(:ok, quantity, method, coin_pair, newer_price),
    do:
      Requests.request(:post, %{
        tapi_method: Utils.get_tapi_method(method),
        coin_pair: coin_pair,
        quantity: :erlang.float_to_binary(quantity, [:compact, {:decimals, 8}]),
        limit_price: newer_price,
        async: true
      })

  def process_order(
        {:ok, %{"response_data" => %{"order" => %{"order_type" => 2} = new_order}}},
        order
      ),
      do:
        process_order(
          Utils.build_valid_order(new_order)
          |> Map.put(:buy_order_id, order.order_id),
          order
        )

  def process_order({:ok, %{"response_data" => %{"order" => new_order}}}, order),
    do:
      process_order(
        Utils.build_valid_order(new_order),
        order
      )

  def process_order({:ok, _}, _), do: nil

  def process_order(nil, _), do: nil

  def process_order(pending_order, _order),
    do: PendingOrdersAgent.add_to_pending_orders_list(pending_order)

  def create_and_add_order(order), do: Order.create_order(order) |> Server.add_order()

  def remove_and_update_order(order) do
    buy_order = Order.get_order(order.buy_order_id)
    Server.remove_order(buy_order)
    Order.update_order(buy_order, %{finished: true})
  end

  def delete_order(id) do
    order = Order.get_order(id)
    Server.remove_order(order)
    Order.update_order(order, %{finished: true})
  end

  def get_account_info_data do
    %{account_info: account_info} = :sys.get_state(TradeServer)
    account_info
  end
end
