defmodule Cryptor.CurrencyAgent do
  @moduledoc """
    Currency Agent
  """
  use Agent

  def start_link(_),
    do:
      Agent.start_link(
        fn ->
          Cryptor.Trader.get_currencies()
          |> Enum.reduce(%{}, fn currency, acc ->
            acc |> Map.put(currency, 0.0)
          end)
        end,
        name: CurrencyAgent
      )

  def get_currency_prices, do: Agent.get(CurrencyAgent, & &1)

  def update_currency_price({currency, price}) do
    Agent.get_and_update(CurrencyAgent, fn currencies ->
      {currencies, Map.put(currencies, currency, String.to_float(price))}
    end)
  end
end
