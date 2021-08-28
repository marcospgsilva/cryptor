defmodule CryptorWeb.OrdersLive do
  @moduledoc """
   Orders Live
  """
  use CryptorWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    %{order_list: order_list} = :sys.get_state(TradeServer)

    case order_list do
      [] ->
        {:ok,
         assign(socket,
           orders: [
             %{
               order_id: 1,
               coin: "Teste",
               quantity: 1.00,
               finished: false,
               type: "buy"
             }
           ]
         )}

      order_list ->
        {:ok, assign(socket, orders: order_list)}
    end
  end

  @impl true
  def handle_event("update_state", _value, socket) do
    IO.inspect("UPDATE_STATE")
    %{order_list: order_list} = :sys.get_state(TradeServer)
    Process.send_after(self(), "update_state", 3000)

    {:noreply, assign(socket, orders: order_list)}
  end
end
