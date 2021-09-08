defmodule Cryptor.Utils do
  @moduledoc """
   Cryptor Utils
  """
  alias Cryptor.Trader

  def get_open_order(coin) do
    account_info = Trader.get_account_info_data()

    case account_info["response_data"]["balance"][coin]["amount_open_orders"] do
      0 ->
        :ok

      _ ->
        nil
    end
  end

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

  def calculate_variation(bought_price, current_price),
    do: (current_price / bought_price - 1) |> Float.round(4)

  def get_date_time, do: DateTime.utc_now() |> DateTime.to_unix()
end
