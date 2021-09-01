defmodule Cryptor.Trader.AmountControl do
  @moduledoc """
  Trader Amount Control
  """
  alias Cryptor.Order

  @eth_minimum_value 0.01
  @ltc_minimum_value 0.03
  @xrp_minimum_value 5.00
  @usdc_minimum_value 6.00
  @bat_maximum_value 12.00
  @bat_minimum_value 8.00
  @enj_maximum_value 6.00
  @enj_minimum_value 3.00
  @chz_maximum_value 25.00
  @chz_minimum_value 10.00
  @btc_maximum_value 0.0002
  @btc_minimum_value 0.0002


  def get_quantity(:sell, _newer_price, %Order{quantity: 0.00000000}), do: nil

  def get_quantity(:sell, _newer_price, %Order{quantity: quantity, coin: "CHZ"}) do
    case quantity < 25 do
      false -> quantity |> Float.round(8)
      _ -> nil
    end
  end

  def get_quantity(:sell, _newer_price, %Order{quantity: quantity}),
    do: quantity |> Float.round(8)

  def get_quantity(:buy, _newer_price, %Order{coin: "BAT"}),
    do: nil

  def get_quantity(:buy, newer_price, %Order{coin: "AXS"}),
    do: newer_price / 50


  def get_quantity(:buy, _newer_price, %Order{quantity: 0.00000000, coin: coin}) do
    case coin do
      "ETH" -> @eth_minimum_value
      "LTC" -> @ltc_minimum_value
      "XRP" -> @xrp_minimum_value
      "USDC" -> @usdc_minimum_value
      "BAT" -> @bat_maximum_value
      "ENJ" -> @enj_maximum_value
      "CHZ" -> @chz_maximum_value
      "BTC" -> @btc_maximum_value
    end
  end

  def get_quantity(:buy, _newer_price, %Order{coin: coin}) do
    case coin do
      "ETH" -> @eth_minimum_value
      "LTC" -> @ltc_minimum_value
      "XRP" -> @xrp_minimum_value
      "USDC" -> @usdc_minimum_value
      "BAT" -> @bat_minimum_value
      "ENJ" -> @enj_minimum_value
      "CHZ" -> @chz_minimum_value
      "BTC" -> @btc_minimum_value
    end
  end
end
