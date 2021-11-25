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
      | line_colour: "#F5B11E",
        line_width: 3,
        fill_colour: "rgba(0, 0, 0, 0.0)",
        height: 50,
        width: 150
    }
  end

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
