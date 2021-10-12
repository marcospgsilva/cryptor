defmodule Cryptor.AmountControl do
  @moduledoc """
  Amount Control
  """

  alias Cryptor.Order

  @currency_amount %{
    "ETH" => 0.01,
    "LTC" => 0.03,
    "XRP" => 5.00,
    "USDC" => 6.00,
    "BAT" => 12.00,
    "ENJ" => 6.00,
    "CHZ" => 25.00,
    "BTC" => 0.0003,
    "BCH" => 0.01
  }

  @currencies_with_platform_fee ["BTC", "USDC", "LTC", "XRP", "ETH", "BCH"]

  def get_quantity(:sell, _newer_price, %Order{quantity: quantity, coin: coin})
      when coin in @currencies_with_platform_fee,
      do: (quantity * 0.997) |> Float.round(8)

  def get_quantity(:sell, _newer_price, %Order{quantity: quantity}),
    do: quantity |> Float.round(8)

  def get_quantity(:buy, _newer_price, %Order{coin: coin}), do: Map.get(@currency_amount, coin)
end
