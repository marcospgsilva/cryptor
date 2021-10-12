defmodule CryptorWeb.AnalysisLive do
  @moduledoc """
   Analysis Live
  """
  use CryptorWeb, :live_view
  alias Cryptor.Trader.TradeServer

  # CLIENT
  def get_analysis_server_data() do
    %{pid_list: pid_list} = TradeServer.get_state()
    Enum.map(pid_list, &build_server_analysis_data/1)
  end

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    schedule_event()
    {:ok, assign(socket, analysis: get_analysis_server_data())}
  end

  @impl true
  def handle_info("update_state", socket),
    do: {:noreply, assign(socket, analysis: get_analysis_server_data())}

  @impl true
  def handle_event(
        "update_percentages",
        %{
          "coin" => coin,
          "sell_percentage" => sell_percentage,
          "buy_percentage" => buy_percentage
        },
        socket
      ) do
    Process.send(
      String.to_existing_atom(coin <> "Server"),
      {
        :update_transaction_limit_percentage,
        String.to_float(sell_percentage),
        String.to_float(buy_percentage)
      },
      []
    )

    {:noreply, socket}
  end

  defp build_server_analysis_data(pid),
    do:
      pid
      |> :sys.get_state()
      |> Map.from_struct()

  defp schedule_event(), do: Process.send_after(self(), "update_state", 9000)
end
