defmodule Cryptor.Trader do
  @moduledoc """
   Trader
  """

  alias Cryptor.Requests
  alias Cryptor.Trader.Server
  alias Cryptor.Trader.AmountControl
  alias Cryptor.Order
  alias Cryptor.Utils
  alias Cryptor.Analysis

  def analyze_transaction(current_value, %Order{price: price, coin: coin} = order) do
    %Analysis{
      sell_percentage_limit: sell_percentage_limit,
      buy_percentage_limit: buy_percentage_limit
    } = :sys.get_state(String.to_existing_atom(coin <> "Server"))

    cond do
      current_value >= price * sell_percentage_limit ->
        place_order(:sell, current_value, order)

      current_value <= price * buy_percentage_limit ->
        place_order(:buy, current_value, order)

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
      {:ok, response} ->
        response

      _ ->
        get_account_info()
    end
  end

  def place_order(method, newer_price, %Order{coin: coin} = order) do
    quantity = AmountControl.get_quantity(method, newer_price, order)

    validate_available_money(
      method,
      quantity,
      newer_price,
      get_account_info_data()
    )
    |> place_order(quantity, method, "BRL#{coin}", newer_price)
    |> process_order(order)
  end

  def validate_available_money(_, _, _, nil), do: nil

  def validate_available_money(_, nil, _, _), do: nil

  def validate_available_money(:sell, _, _, _), do: :ok

  def validate_available_money(:buy, quantity, newer_price, account_info) do
    available_brl = Utils.get_available_value(account_info, "brl")
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

  def process_order({:ok, %{"response_data" => %{"order" => new_order}}}, order) do
    attrs = %{
      order_id: new_order["order_id"],
      quantity: new_order["quantity"] |> String.to_float(),
      price: new_order["limit_price"] |> String.to_float(),
      coin: new_order["coin_pair"] |> String.split("BRL") |> List.last(),
      type: Utils.get_order_type(new_order["order_type"])
    }

    process_order(attrs, order)
  end

  def process_order({:ok, _}, _), do: nil

  def process_order(nil, _), do: nil

  def process_order(%{type: "buy"} = attrs, _order) do
    Order.create_order(attrs) |> Server.add_order()
  end

  def process_order(%{type: _}, order) do
    Server.remove_order(order)
    Order.update_order(order, %{finished: true})
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
