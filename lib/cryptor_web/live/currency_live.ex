defmodule CryptorWeb.CurrencyLive do
  @moduledoc """
   Currency Live
  """

  use CryptorWeb, :live_view
  alias Cryptor.Currency
  alias Cryptor.Trader.Server
  alias Ecto.Changeset

  # SERVER
  @impl true
  def mount(_params, _session, socket),
    do: {:ok, assign(socket, error: false)}

  @impl true
  def handle_event("create_currency", %{"currency" => currency}, socket) do
    currency = String.upcase(currency)

    case Currency.create_currency(%{coin: currency}) do
      %Changeset{valid?: false} ->
        {:noreply, assign(socket, error: true)}

      currency ->
        [currency.coin]
        |> Server.start_currencies_analysis()

        {:noreply, assign(socket, error: false)}
    end
  end
end
