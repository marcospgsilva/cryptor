defmodule CryptorWeb.AnalysisLive do
  @moduledoc """
   Analysis Live
  """
  use CryptorWeb, :live_view

  alias Cryptor.{
    Trader,
    Server,
    ProcessRegistry,
    Bot
  }

  # CLIENT
  def get_analysis_server_data(socket) do
    user_id = get_user_id_from_socket(socket)

    case user_id do
      nil ->
        []

      id ->
        Trader.get_currencies()
        |> Enum.map(fn currency ->
          build_server_analysis_data(id, currency)
        end)
    end
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
    user_id = get_user_id_from_socket(socket)
    pids = ProcessRegistry.get_servers_registry(user_id, coin)

    Process.send(
      pids[:bot_pid],
      {
        :update_transaction_limit_percentage,
        String.to_float(sell_percentage),
        String.to_float(buy_percentage)
      },
      []
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_analysis_server", %{"currency" => currency}, socket) do
    user_id = get_user_id_from_socket(socket)

    case Bot.get_bot(user_id, currency) do
      nil ->
        {:ok, bot} = Bot.create_bot(%{user_id: user_id})
        Server.start_bot_server(bot, user_id)

      bot ->
        pids = ProcessRegistry.get_servers_registry(user_id, currency)

        case pids[:bot_pid] do
          nil ->
            Server.start_bot_server(bot, user_id)

          pid ->
            Bot.update_bot(bot, %{active: false})
            Process.exit(pid, :kill)
        end
    end

    {:noreply, socket}
  end

  defp build_server_analysis_data(nil, _currency), do: nil

  defp build_server_analysis_data(user_id, currency) do
    case ProcessRegistry.get_servers_registry(user_id, currency)[:bot_pid] do
      :undefined ->
        nil

      pid ->
        %{
          bot: bot,
          orders: orders,
          current_price: current_price,
          buy_percentage_limit: buy_percentage_limit
        } = Cryptor.BotServer.get_state(pid)

        %{
          currency: bot.currency,
          active: bot.active,
          orders: orders,
          current_price: current_price,
          sell_percentage_limit: bot.sell_percentage_limit,
          buy_percentage_limit: buy_percentage_limit
        }
    end
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 9000)

  defp get_user_id_from_socket(socket) do
    case socket.assigns[:current_user] do
      nil -> nil
      current_user -> current_user.id
    end
  end
end
