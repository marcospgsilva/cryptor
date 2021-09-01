defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view
  alias CryptorWeb.AnalysisView
  alias Cryptor.Utils

  @impl true
  def mount(_params, _session, socket) do
    %{pid_list: pid_list, account_info: account_info} = :sys.get_state(TradeServer)

    available_brl = Utils.get_available_value(account_info, "brl")

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
    %{pid_list: pid_list, account_info: account_info} = :sys.get_state(TradeServer)

    orders = AnalysisView.render_currencies(pid_list)

    case Utils.get_available_value(account_info, "brl") do
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
    Cryptor.Trader.delete_order(id |> String.to_integer())
    {:noreply, socket}
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 3000)
end
