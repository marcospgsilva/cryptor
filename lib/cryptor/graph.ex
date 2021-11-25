defmodule Cryptor.Graph do
  @moduledoc """
   Cryptor Graph
  """
  alias Contex.Sparkline

  def make_plot(data),
    do:
      Sparkline.new(data)
      |> update_sparkline_style()
      |> Sparkline.draw()

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
    latest_value = data |> List.last()
    if first_value <= latest_value, do: "#10B981", else: "#EF4444"
  end

  defp set_line_colour(%Contex.Sparkline{}), do: "#10B981"

  def build_order_history(_socket, _order_id, _initial_value, 0.0), do: []

  def build_order_history(socket, order_id, initial_value, current_price) do
    case socket.assigns.orders do
      [] ->
        [initial_value]

      orders ->
        order = Enum.find(orders, &(&1.order_id == order_id))
        [current_price | order.data]
    end
  end
end
