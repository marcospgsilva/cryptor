defmodule CryptorWeb.PendingOrdersLive do
  @moduledoc """
   PendingOrders Live
  """
  use CryptorWeb, :live_view
  alias Cryptor.Trader
  alias Cryptor.ProcessRegistry
  alias Cryptor.Orders.PendingOrdersAgent
  alias Cryptor.CurrencyServer

  # SERVER
  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket)
    user_id = get_user_id_from_socket(socket)

    case ProcessRegistry.get_servers_registry(user_id) do
      nil ->
        schedule_event()
        {:ok, assign(socket, pending_orders: [])}

      _ ->
        schedule_event()

        {:ok,
         assign(socket,
           pending_orders: render_pending_orders(user_id)
         )}
    end
  end

  @impl true
  def handle_info("update_state", socket) do
    user_id = get_user_id_from_socket(socket)
    pending_orders = render_pending_orders(user_id)

    case ProcessRegistry.get_servers_registry(user_id) do
      nil ->
        {:noreply, socket}

      _ ->
        schedule_event()
        {:noreply, assign(socket, pending_orders: pending_orders)}
    end
  end

  @impl true
  def handle_event("delete_order", %{"order_id" => id}, socket) do
    user_id = get_user_id_from_socket(socket)
    Trader.remove_order_from_pending_list(String.to_integer(id), user_id)
    pending_orders = render_pending_orders(user_id)
    {:noreply, assign(socket, pending_orders: pending_orders)}
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 3000)

  defp get_user_id_from_socket(socket) do
    case socket.assigns[:current_user] do
      nil -> nil
      current_user -> current_user.id
    end
  end

  def render_pending_orders(nil), do: []

  def render_pending_orders(user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id)

    case PendingOrdersAgent.get_pending_orders_list(pids[:pending_orders_pid]) do
      [] ->
        []

      orders ->
        orders
        |> Enum.map(fn order ->
          current_price = CurrencyServer.get_current_price(order.coin)

          %{
            order_id: order.order_id,
            coin: order.coin,
            value: order.price,
            quantity: order.quantity,
            current_price: current_price,
            type: order.type
          }
        end)
    end
  end
end
