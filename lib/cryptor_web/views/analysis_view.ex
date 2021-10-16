defmodule CryptorWeb.AnalysisView do
  use CryptorWeb, :view
  alias Cryptor.Order
  alias Cryptor.Utils
  alias Cryptor.Orders.OrdersAgent

  def render("analysis.json", %{analysis: %{order_list: order_list}}) do
    %{
      moedas: render_currencies(),
      ordens: render_orders(order_list)
    }
  end

  def render_orders(order_list) do
    order_list
    |> Enum.map(fn %Order{} = order ->
      %{
        id_do_pedido: order.order_id,
        moeda: order.coin,
        quantidade: order.quantity,
        valor: order.price,
        tipo_de_pedido: order.type,
        concluido: order.finished
      }
    end)
  end

  def render_currencies() do
    OrdersAgent.get_order_list()
    |> Enum.map(fn order ->
      %{current_price: current_price} =
        :sys.get_state(String.to_existing_atom("#{order.coin}Server"))

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
