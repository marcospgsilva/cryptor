defmodule CryptorWeb.AnalysisLive do
  @moduledoc """
   Analysis Live
  """
  use CryptorWeb, :live_view
  alias Cryptor.Analysis

  @impl true
  def mount(_params, _session, socket) do
    analysis = get_analysis_servers()
    schedule_event()
    {:ok, assign(socket, analysis: analysis)}
  end

  @impl true
  def handle_info("update_state", socket) do
    analysis = get_analysis_servers()
    {:noreply, assign(socket, analysis: analysis)}
  end

  def get_analysis_servers() do
    %{pid_list: pid_list} = :sys.get_state(TradeServer)

    pid_list
    |> Enum.map(fn pid ->
      %Analysis{coin: coin, orders: orders, current_value: current_value} = :sys.get_state(pid)

      %{
        coin: coin,
        orders: Enum.count(orders),
        current_value: current_value
      }
    end)
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 9000)
end
