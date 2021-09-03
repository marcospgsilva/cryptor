defmodule Cryptor.Utils do
  @moduledoc """
   Cryptor Utils
  """

  def get_available_value(account_info, coin) do
    case account_info["response_data"]["balance"][coin]["available"] do
      nil ->
        nil

      available ->
        String.to_float(available)
    end
  end

  def get_tapi_method(:buy), do: "place_buy_order"

  def get_tapi_method(:sell), do: "place_sell_order"

  def get_order_type(2), do: "sell"

  def get_order_type(1), do: "buy"

  def format_for_brl(value) when is_float(value),
    do:
      value
      |> Float.to_string()
      |> String.replace(".", ",")

  def format_for_brl(value), do: value

  def get_date_time, do: DateTime.utc_now() |> DateTime.to_unix()
end
