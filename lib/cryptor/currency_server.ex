defmodule Cryptor.CurrencyServer do
  use GenServer
  alias Cryptor.Trader

  def start_link(%{currency: currency}) do
    GenServer.start_link(
      __MODULE__,
      %{currency: currency, current_price: 0.0},
      name: String.to_atom(currency <> "Server")
    )
  end

  def get_current_price(currency) do
    %{current_price: current_price} =
      :sys.get_state(String.to_existing_atom(currency <> "Server"))

    current_price
  end

  @impl true
  def init(state) do
    schedule_get_currency_price(state.currency)
    {:ok, state}
  end

  @impl true
  def handle_info(:get_current_price, %{currency: currency} = state) do
    case Trader.get_currency_price(currency) do
      {:ok, current_price} ->
        schedule_get_currency_price(currency)
        {:noreply, %{state | current_price: current_price}}

      _ ->
        schedule_get_currency_price(currency)
        {:noreply, state}
    end
  end

  def schedule_get_currency_price(currency),
    do:
      Process.send_after(
        String.to_existing_atom(currency <> "Server"),
        :get_current_price,
        Enum.random(7_000..8_000)
      )
end
