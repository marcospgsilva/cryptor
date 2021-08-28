defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    case render_orders() do
      [] ->
        schedule_event()

        {:ok,
         assign(socket,
           orders: [
             %{
               coin: "Teste",
               price: 1.00,
               current_value: false,
               variation: 1.2
             }
           ]
         )}

      orders ->
        schedule_event()
        {:ok, assign(socket, orders: orders)}
    end
  end

  @impl true
  def handle_info("update_state", socket) do
    IO.inspect("UPDATE_STATE")
    schedule_event()
    {:noreply, assign(socket, orders: render_orders())}
  end

  def render_orders() do
    %{pid_list: pid_list} = :sys.get_state(TradeServer)

    pid_list
    |> Enum.map(fn pid ->
      %{orders: orders, current_value: current_value} = :sys.get_state(pid)

      orders
      |> Enum.map(fn order ->
        %{
          coin: order.coin,
          price: order.price,
          current_value: current_value,
          variation: calculate_variation(order.price, current_value)
        }
      end)
    end)
    |> Enum.concat()
  end

  defp schedule_event(), do: Process.send_after(self(), "update_state", 3000)

  defp calculate_variation(bought_price, current_price),
    do: (current_price / bought_price - 1) |> Float.round(8)
end
