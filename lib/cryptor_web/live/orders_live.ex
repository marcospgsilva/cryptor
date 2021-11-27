defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view
  alias Cryptor.Trader
  alias Cryptor.Analysis
  alias Cryptor.ProcessRegistry
  alias Cryptor.Utils
  alias Cryptor.Orders.OrdersAgent
  alias Cryptor.Graph

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    socket =
      assign_defaults(session, socket)
      |> assign(orders: [])

    user_id = get_user_id_from_socket(socket)

    case ProcessRegistry.get_servers_registry(user_id) do
      nil ->
        schedule_event()
        {:ok, assign(socket, orders: [], available_brl: 0.0)}

      pids ->
        case pids[:analysis_pid] do
          nil ->
            schedule_event()
            {:ok, assign(socket, orders: [], available_brl: 0.0)}

          pid ->
            %{account_info: account_info} = Analysis.get_state(pid)
            {:ok, available_brl} = Utils.get_available_amount(account_info, "USDT")

            schedule_event()

            {:ok,
             assign(socket,
               orders: render_currencies(user_id, socket),
               available_brl: available_brl
             )}
        end
    end
  end

  @impl true
  def handle_info("update_state", socket) do
    user_id = get_user_id_from_socket(socket)
    orders = render_currencies(user_id, socket)

    case ProcessRegistry.get_servers_registry(user_id) do
      nil ->
        schedule_event()
        {:noreply, socket}

      pids ->
        %{account_info: account_info} = Analysis.get_state(pids[:analysis_pid])
        {:ok, available_brl} = Utils.get_available_amount(account_info, "USDT")
        schedule_event()
        {:noreply, assign(socket, orders: orders, available_brl: available_brl)}
    end
  end

  @impl true
  def handle_event("delete_order", %{"order_id" => id}, socket) do
    user_id = get_user_id_from_socket(socket)
    pids = ProcessRegistry.get_servers_registry(user_id)
    Trader.delete_order(String.to_integer(id), user_id)
    orders = OrdersAgent.get_order_list(pids[:orders_pid])

    %{account_info: account_info} = Analysis.get_state(pids[:analysis_pid])
    {:ok, available_brl} = Utils.get_available_amount(account_info, "brl")

    Process.sleep(1000)
    {:noreply, assign(socket, orders: orders, available_brl: available_brl)}
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 3000)

  defp get_user_id_from_socket(socket) do
    case socket.assigns[:current_user] do
      nil -> nil
      current_user -> current_user.id
    end
  end

  def render_currencies(nil, _), do: []

  def render_currencies(user_id, socket) do
    pids = ProcessRegistry.get_servers_registry(user_id)

    case OrdersAgent.get_order_list(pids[:orders_pid]) do
      [] ->
        []

      orders ->
        orders
        |> Enum.map(fn order ->
          current_price = Cryptor.CurrencySocket.get_current_price(order.coin)

          %{
            id: order.id,
            order_id: order.order_id,
            coin: order.coin,
            bought_value: order.price,
            quantity: order.quantity,
            current_price: current_price,
            variation: Utils.calculate_variation(order.price, current_price),
            data: Graph.build_order_history(socket, order.order_id, order.price, current_price)
          }
        end)
    end
  end
end
