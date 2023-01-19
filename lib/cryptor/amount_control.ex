defmodule Cryptor.AmountControl do
  @moduledoc """
  Amount Control
  """

  alias Cryptor.Orders.Order

  def get_quantity(:buy, _newer_price, %Order{fee: nil}, buy_amount) do
    buy_amount
  end

  def get_quantity(:sell, _newer_price, %Order{quantity: quantity, fee: fee}, _buy_amount) do
    fee = String.to_float(fee)

    quantity
    |> Kernel.-(fee)
    |> Float.round(8)
  end
end
