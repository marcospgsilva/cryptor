defmodule CryptorWeb.AnalysisView do
  use CryptorWeb, :view
  alias Cryptor.Order
  alias Cryptor.Utils
  alias Cryptor.Trader.TradeServer

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
    TradeServer.get_currencies()
    |> Enum.map(fn currency ->
      %{orders: orders, current_price: current_price} =
        :sys.get_state(String.to_existing_atom("#{currency}Server"))

      order_list =
        orders
        |> Enum.filter(fn order -> order.quantity != 0.0 end)

      order_list
      |> Enum.map(fn order ->
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
    end)
    |> Enum.concat()
  end
end
