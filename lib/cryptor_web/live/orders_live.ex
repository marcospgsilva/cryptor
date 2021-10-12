defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view
  alias CryptorWeb.AnalysisView
  alias Cryptor.Trader
  alias Cryptor.Trader.TradeServer
  alias Cryptor.Utils

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    %{pid_list: pid_list, account_info: account_info} = TradeServer.get_state()
    available_brl = Utils.get_available_amount(account_info, "brl")
    socket = assign_defaults(session, socket)

    case AnalysisView.render_currencies(pid_list) do
      nil ->
        schedule_event()
        {:ok, assign(socket, orders: [], available_brl: 0.00)}

      orders ->
        schedule_event()
        {:ok, assign(socket, orders: orders, available_brl: available_brl)}
    end
  end

  @impl true
  def handle_info("update_state", socket) do
    %{pid_list: pid_list, account_info: account_info} = TradeServer.get_state()

    orders = AnalysisView.render_currencies(pid_list)

    case Utils.get_available_amount(account_info, "brl") do
      nil ->
        schedule_event()
        {:noreply, assign(socket, orders: orders)}

      available_brl ->
        schedule_event()
        {:noreply, assign(socket, orders: orders, available_brl: available_brl)}
    end
  end

  @impl true
  def handle_event("delete_order", %{"order_id" => id}, socket) do
    Trader.delete_order(id |> String.to_integer())
    {:noreply, socket}
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 3000)
end
