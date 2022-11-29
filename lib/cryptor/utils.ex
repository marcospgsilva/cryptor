defmodule Cryptor.Utils do
  @moduledoc """
   Cryptor Utils
  """
  alias Cryptor.Orders.Order

  def build_valid_order(new_order) do
    %Order{}
    |> Map.put(:order_id, new_order["order_id"])
    |> Map.put(:quantity, String.to_float(new_order["quantity"]))
    |> Map.put(:price, String.to_float(new_order["limit_price"]))
    |> Map.put(
      :coin,
      new_order["coin_pair"]
      |> String.split("BRL")
      |> List.last()
    )
    |> Map.put(:fee, new_order["fee"])
    |> Map.put(:type, get_order_type(new_order["order_type"]))
    |> Map.put(:buy_order_id, nil)
    |> Map.put(:filled, false)
  end

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

  def format_for_brl(0.0 = value) do
    value
    |> Float.to_string()
    |> String.replace(".", ",0")
  end

  def format_for_brl(value) when is_float(value) do
    value
    |> Float.to_string()
    |> String.replace(".", ",")
  end

  def format_for_brl(value) when is_binary(value) do
    String.replace(value, ".", ",")
  end

  def format_for_brl(value), do: value

  def calculate_variation(bought_price, current_price) do
    current_price
    |> Kernel./(bought_price - 1)
    |> Kernel.*(100)
    |> Float.round(4)
  end

  def get_date_time do
    DateTime.to_unix(DateTime.utc_now())
  end

  def get_timeout, do: :infinity

  def format_float_with_decimals(value) do
    :erlang.float_to_binary(value, [:compact, {:decimals, 8}])
  end

  def validate_float(value) do
    try do
      String.to_float(value)
    rescue
      _e -> String.to_integer(value) * 1.0
    end
  end
end
