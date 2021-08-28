defmodule CryptorWeb.AnalysisView do
  use CryptorWeb, :view
  alias Cryptor.Order

  def render("analysis.json", %{analysis: %{pid_list: pid_list, order_list: order_list}}) do
    %{
      moedas: render_currencies(pid_list),
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

  def render_currencies([]), do: nil

  def render_currencies(nil), do: nil

  def render_currencies(pid_list) do
    pid_list
    |> Enum.map(fn pid ->
      %{orders: orders, current_value: current_value} = :sys.get_state(pid)

      orders
      |> Enum.map(fn order ->
        %{
          moeda: order.coin,
          comprada_por: order.price,
          valor_atual: current_value,
          variacao: calculate_variation(order.price, current_value)
        }
      end)
    end)
    |> Enum.concat()
  end

  defp calculate_variation(bought_price, current_price),
    do: (current_price / bought_price - 1) |> Float.round(8)
end
