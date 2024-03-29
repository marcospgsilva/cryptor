defmodule Cryptor.Graphs.Chart do
  @moduledoc """
   Cryptor Chart
  """
  alias Contex.Sparkline

  @positive_graph_color "#10B981"
  @negative_graph_color "#EF4444"

  def make_plot(data) do
    data
    |> Sparkline.new()
    |> update_sparkline_style()
    |> Sparkline.draw()
  end

  defp update_sparkline_style(%Contex.Sparkline{} = sparkline) do
    %{
      sparkline
      | line_colour: set_line_colour(sparkline),
        line_width: 2,
        fill_colour: "rgba(0, 0, 0, 0.0)",
        height: 50,
        width: Enum.count(sparkline.data) * 1.5 * 10
    }
  end

  defp set_line_colour(%Contex.Sparkline{data: [first_value | _] = data}) do
    if first_value <= List.last(data),
      do: @positive_graph_color,
      else: @negative_graph_color
  end

  defp set_line_colour(%Contex.Sparkline{}), do: @positive_graph_color

  def build_order_history(_socket, _order_id, _initial_value, 0.0), do: []

  def build_order_history(socket, order_id, initial_value, current_price) do
    case socket.assigns.orders do
      [] ->
        [initial_value]

      orders ->
        case Enum.find(orders, &(&1.order_id == order_id)) do
          nil ->
            [initial_value]

          order ->
            [current_price | order.data]
        end
    end
  end
end
