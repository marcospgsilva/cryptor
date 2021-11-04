defmodule CryptorWeb.AnalysisView do
  use CryptorWeb, :view
  alias Cryptor.Utils
  alias Cryptor.Orders.OrdersAgent
  alias Cryptor.ProcessRegistry

  def render("analysis.json", analysis), do: analysis

  def render_currencies(nil), do: []

  def render_currencies(user_id) do
    pids = ProcessRegistry.get_servers_registry(user_id)

    case OrdersAgent.get_order_list(pids[:orders_pid]) do
      [] ->
        []

      orders ->
        orders
        |> Enum.map(fn order ->
          pids = ProcessRegistry.get_servers_registry(user_id, order.coin)
          %{current_price: current_price} = :sys.get_state(pids[:bot_pid])

          %{
            id: order.id,
            order_id: order.order_id,
            coin: order.coin,
            bought_value: order.price,
            quantity: order.quantity,
            current_price: current_price,
            variation: Utils.calculate_variation(order.price, current_price)
          }
        end)
    end
  end
end
