defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view
  alias CryptorWeb.AnalysisView
  alias Cryptor.Trader
  alias Cryptor.Analysis
  alias Cryptor.ProcessRegistry
  alias Cryptor.Utils

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    user_id = get_user_id_from_socket(socket)

    case AnalysisView.render_currencies(user_id) do
      [] ->
        schedule_event()
        {:ok, assign(socket, orders: [], available_brl: 0.00)}

      orders ->
        schedule_event()
        pids = ProcessRegistry.get_servers_registry(user_id)

        %{account_info: account_info} = Analysis.get_state(pids[:analysis_pid])
        {:ok, available_amount} = Utils.get_available_amount(account_info, "brl")

        {:ok, assign(socket, orders: orders, available_brl: available_amount)}
    end
  end

  @impl true
  def handle_info("update_state", socket) do
    user_id = get_user_id_from_socket(socket)
    orders = AnalysisView.render_currencies(user_id)

    case ProcessRegistry.get_servers_registry(user_id) do
      nil ->
        {:noreply, socket}

      pids ->
        %{account_info: account_info} = Analysis.get_state(pids[:analysis_pid])
        {:ok, available_brl} = Utils.get_available_amount(account_info, "brl")
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

  defp get_user_id_from_socket(socket) do
    case socket.assigns[:current_user] do
      nil -> nil
      current_user -> current_user.id
    end
  end
end
