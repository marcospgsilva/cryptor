defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view
  alias CryptorWeb.AnalysisView

  @impl true
  def mount(_params, _session, socket) do
    %{pid_list: pid_list} = :sys.get_state(TradeServer)

    case AnalysisView.render_currencies(pid_list) do
      nil ->
        schedule_event()

        {:ok, assign(socket, orders: [])}

      orders ->
        schedule_event()
        {:ok, assign(socket, orders: orders)}
    end
  end

  @impl true
  def handle_info("update_state", socket) do
    %{pid_list: pid_list} = :sys.get_state(TradeServer)

    orders = AnalysisView.render_currencies(pid_list)
    schedule_event()
    {:noreply, assign(socket, orders: orders)}
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 3000)
end
