defmodule Cryptor.Orders.OrdersAgent do
  @moduledoc """
  Orders Agent
  """
  use Agent
  alias Cryptor.Orders

  def start_link(%{name: name, user_id: user_id}) do
    Agent.start_link(fn -> Orders.get_orders(user_id) end, name: name)
  end

  def get_order_list(pid) do
    Agent.get(pid, & &1)
  end

  def add_to_order_list(pid, new_order) do
    Agent.update(pid, fn orders -> [new_order | orders] end)
  end

  def remove_from_order_list(pid, order_to_be_removed) do
    Agent.update(pid, fn orders ->
      Enum.reject(orders, &(order_to_be_removed.order_id == &1.order_id))
    end)
  end
end
