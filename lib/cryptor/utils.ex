defmodule Cryptor.Utils do
  @moduledoc """
   Cryptor Utils
  """
  alias Cryptor.Orders.Order

  def build_valid_order(new_order),
    do: %Order{
      order_id: new_order["order_id"],
      quantity: new_order["quantity"] |> String.to_float(),
      price: new_order["limit_price"] |> String.to_float(),
      coin: new_order["coin_pair"] |> String.split("BRL") |> List.last(),
      fee: new_order["fee"],
      type: get_order_type(new_order["order_type"]),
      buy_order_id: nil,
      filled: false
    }

  def get_available_amount(account_info, coin) do
    case account_info["response_data"]["balance"][String.downcase(coin)]["available"] do
      nil ->
        {:ok, 0.00}

      available ->
        {:ok, String.to_float(available)}
    end
  end

  def get_tapi_method(:buy), do: "place_buy_order"

  def get_tapi_method(:sell), do: "place_sell_order"

  def get_order_type(2), do: "sell"

  def get_order_type(1), do: "buy"

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
    do: (current_price / bought_price - 1) |> Float.round(4)

  def get_date_time, do: DateTime.utc_now() |> DateTime.to_unix()

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
