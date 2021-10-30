defmodule CryptorWeb.AnalysisLive do
  @moduledoc """
   Analysis Live
  """
  use CryptorWeb, :live_view
  alias Cryptor.Trader.TradeServer
  alias Cryptor.ProcessRegistry

  # CLIENT
  def get_analysis_server_data(socket) do
    user_id = get_user_id_from_socket(socket)

    TradeServer.get_currencies()
    |> Enum.map(fn currency ->
      build_server_analysis_data(currency, user_id)
    end)
  end

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    schedule_event()
    {:ok, assign(socket, analysis: get_analysis_server_data(socket))}
  end

  @impl true
  def handle_info("update_state", socket),
    do: {:noreply, assign(socket, analysis: get_analysis_server_data(socket))}

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

  defp build_server_analysis_data(currency, user_id),
    do:
      ProcessRegistry.whereis_name({user_id, "#{currency}Server"})
      |> :sys.get_state()
      |> Map.from_struct()

  defp schedule_event(), do: Process.send_after(self(), "update_state", 9000)

  defp get_user_id_from_socket(socket), do: socket[:current_user][:id]
end
