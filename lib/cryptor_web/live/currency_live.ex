defmodule CryptorWeb.CurrencyLive do
  @moduledoc """
   Currency Live
  """

  use CryptorWeb, :live_view
  alias Cryptor.Currencies
  alias Ecto.Changeset

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    {:ok, assign(socket, error: false)}
  end

  @impl true
  def handle_event("create_currency", %{"currency" => currency}, socket) do
    currency = String.upcase(currency)

    case Currencies.create_currency(%{coin: currency}) do
      %Changeset{valid?: false} ->
        {:noreply, assign(socket, error: true)}

      _ ->
        {:noreply, assign(socket, error: false)}
    end
  end
end
