defmodule CryptorWeb.AnalysisLive do
  @moduledoc """
   Analysis Live
  """
  use CryptorWeb, :live_view

  alias Cryptor.{
    Utils,
    BotServer,
    CurrencySocket,
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
        |> Enum.reject(&(&1 == nil))
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
  def handle_info("update_state", socket) do
    schedule_event()
    {:noreply, assign(socket, analysis: get_analysis_server_data(socket))}
  end

  @impl true
  def handle_event(
        "update_bot",
        %{
          "coin" => coin,
          "sell_percentage" => sell_percentage,
          "buy_percentage" => buy_percentage,
          "buy_amount" => buy_amount,
          "max_orders_amount" => max_orders_amount,
          "sell_active" => sell_active,
          "buy_active" => buy_active,
          "bot_active" => bot_active
        },
        socket
      ) do
    user_id = get_user_id_from_socket(socket)
    pids = ProcessRegistry.get_servers_registry(user_id, coin)

    Process.send(
      pids[:bot_pid],
      {
        :update_bot,
        %{
          sell_percentage: Utils.validate_float(sell_percentage),
          buy_percentage: Utils.validate_float(buy_percentage),
          buy_amount: buy_amount,
          max_orders_amount: Utils.validate_float(max_orders_amount) |> round(),
          sell_active: String.to_existing_atom(sell_active),
          buy_active: String.to_existing_atom(buy_active),
          bot_active: String.to_existing_atom(bot_active)
        }
      },
      []
    )

    Process.sleep(1000)
    {:noreply, assign(socket, analysis: get_analysis_server_data(socket))}
  end

  defp build_server_analysis_data(nil, _currency), do: nil

  defp build_server_analysis_data(user_id, currency) do
    pids = ProcessRegistry.get_servers_registry(user_id, currency)

    case pids[:bot_pid] do
      :undefined ->
        {:ok, bot} = Bot.create_bot(%{user_id: user_id, currency: currency})

        with {:ok, _pid} <- Server.start_bot_server(bot, user_id) do
          ProcessRegistry.get_servers_registry(user_id, currency)
          |> build_bot_currency()
        end

      _ ->
        build_bot_currency(pids)
    end
  end

  def build_bot_currency(pids) do
    %{bot: bot} = BotServer.get_state(pids[:bot_pid])

    orders =
      Cryptor.Orders.OrdersAgent.get_order_list(pids[:orders_pid])
      |> Enum.filter(&(&1.coin == bot.currency))

    current_price = CurrencySocket.get_current_price(bot.currency)

    %{
      currency: bot.currency,
      active: bot.active,
      orders: orders,
      current_price: current_price,
      sell_percentage_limit: bot.sell_percentage_limit,
      buy_percentage_limit: bot.buy_percentage_limit,
      buy_amount: bot.buy_amount,
      max_orders_amount: bot.max_orders_amount,
      buy_active: bot.buy_active,
      sell_active: bot.sell_active
    }
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 9000)

  defp get_user_id_from_socket(socket) do
    case socket.assigns[:current_user] do
      nil -> nil
      current_user -> current_user.id
    end
  end
end
