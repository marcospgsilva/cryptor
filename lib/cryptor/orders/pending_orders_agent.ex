defmodule Cryptor.Orders.PendingOrdersAgent do
  @moduledoc """
   Pending Orders Agent
  """
  use Agent
  alias Cryptor.Orders

  def start_link(%{name: name, user_id: user_id}),
    do: Agent.start_link(fn -> Orders.get_pending_orders(user_id) end, name: name)

  def get_pending_orders_list(pid), do: Agent.get(pid, & &1)

  def add_to_pending_orders_list(pid, new_order) do
    Agent.get_and_update(pid, fn pending_orders ->
      {pending_orders, [new_order | pending_orders]}
    end)
  end

  def remove_from_pending_orders_list(pid, order_to_be_removed) do
    Agent.get_and_update(pid, fn pending_orders ->
      {pending_orders,
       pending_orders |> Enum.reject(&(order_to_be_removed.order_id == &1.order_id))}
    end)
  end
end
