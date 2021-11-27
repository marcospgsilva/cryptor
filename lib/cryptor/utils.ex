defmodule Cryptor.Utils do
  @moduledoc """
   Cryptor Utils
  """
  alias Cryptor.Orders.Order

  def build_valid_order(new_order),
    do: %Order{
      order_id: new_order["orderId"],
      quantity: new_order["origQty"] |> String.to_float(),
      price: new_order["price"] |> String.to_float(),
      coin: new_order["symbol"] |> String.split("USDT") |> List.first(),
      fee: get_fee(new_order["fills"]),
      type: get_order_type(new_order["side"]),
      buy_order_id: nil,
      filled: false
    }

  def get_fee([]), do: nil

  def get_fee(fills) do
    order = fills |> List.first()
    order["commission"]
  end

  def get_available_amount(nil, _coin), do: {:ok, 0.0}

  def get_available_amount([], _coin), do: {:ok, 0.0}

  def get_available_amount(balances, coin) do
    case balances
         |> Enum.find({:ok, 0.00}, fn balance ->
           balance["asset"] == coin
         end) do
      {:ok, 0.00} = default ->
        default

      balance ->
        available = balance["free"]
        {:ok, String.to_float(available)}
    end
  end

  def get_tapi_method(:buy), do: "BUY"

  def get_tapi_method(:sell), do: "SELL"

  def get_order_type("SELL"), do: "sell"

  def get_order_type("BUY"), do: "buy"

  def get_order_type(:sell), do: "sell"

  def get_order_type(:buy), do: "buy"

  def format_for_brl(0.0 = value),
    do:
      value
      |> Float.to_string()
      |> String.replace(".", ",0")

  def format_for_brl(value) when is_float(value),
    do:
      value
      |> Float.to_string()
      |> String.replace(".", ",")

  def format_for_brl(value) when is_binary(value),
    do:
      value
      |> String.replace(".", ",")

  def format_for_brl(value), do: value

  def calculate_variation(bought_price, current_price),
    do: ((current_price / bought_price - 1) * 100) |> Float.round(4)

  def get_date_time, do: DateTime.utc_now() |> DateTime.to_unix(:millisecond)

  def get_timeout, do: :infinity

  def format_float_with_decimals(value),
    do: :erlang.float_to_binary(value, [:compact, {:decimals, 8}])

  def validate_float(value) do
    try do
      String.to_float(value)
    rescue
      _e -> String.to_integer(value) * 1.0
    end
  end
end
