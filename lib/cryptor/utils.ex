defmodule Cryptor.Utils do
  @moduledoc """
   Cryptor Utils
  """
  alias Cryptor.Trader

  def get_available_value(nil, _) do
    case Trader.get_account_info() do
      nil ->
        nil

      _ = response ->
        GenServer.cast(TradeServer, {:update_account_info, response})
        response
    end
  end

  def get_available_value(account_info, coin),
    do:
      account_info["response_data"]["balance"][coin]["available"]
      |> String.to_float()

  def get_tapi_method(:buy), do: "place_buy_order"

  def get_tapi_method(:sell), do: "place_sell_order"

  def get_order_type(2), do: "sell"

  def get_order_type(1), do: "buy"
end
