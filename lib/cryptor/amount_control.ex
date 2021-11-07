defmodule Cryptor.AmountControl do
  @moduledoc """
  Amount Control
  """

  alias Cryptor.Orders.Order

  def get_quantity(:sell, _newer_price, %Order{quantity: quantity, fee: fee}, _buy_amount)
      when not is_nil(fee),
      do: (quantity - String.to_float(fee)) |> Float.round(8)

  def get_quantity(:buy, _newer_price, _order, buy_amount), do: buy_amount
end
