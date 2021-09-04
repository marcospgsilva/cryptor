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
      %Analysis{
        coin: coin,
        orders: orders,
        current_value: current_value,
        sell_percentage_limit: sell_percentage_limit,
        buy_percentage_limit: buy_percentage_limit
      } = :sys.get_state(pid)

      %{
        coin: coin,
        orders: Enum.count(orders),
        current_value: current_value,
        sell_percentage_limit: sell_percentage_limit,
        buy_percentage_limit: buy_percentage_limit
      }
    end)
  end

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
    sell_percentage = String.to_float(sell_percentage)
    buy_percentage = String.to_float(buy_percentage)

    Process.send(
      String.to_existing_atom(coin <> "Server"),
      {:update_transaction_limit_percentage, sell_percentage, buy_percentage},
      []
    )

    {:noreply, socket}
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 9000)
end
