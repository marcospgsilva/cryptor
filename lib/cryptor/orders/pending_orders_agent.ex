defmodule Cryptor.Orders.PendingOrdersAgent do
  @moduledoc """
   Pending Orders Agent
  """
  use Agent

  def start_link(%{name: name}), do: Agent.start_link(fn -> [] end, name: name)

  def get_pending_orders_list(pid), do: Agent.get(pid, & &1)

  def add_to_pending_orders_list(pid, new_order) do
    Agent.get_and_update(pid, fn pending_orders ->
      {pending_orders, [new_order | pending_orders]}
    end)
  end

  def remove_from_pending_orders_list(pid, order_to_be_removed) do
    Agent.get_and_update(pid, fn pending_orders ->
      {pending_orders, List.delete(pending_orders, order_to_be_removed)}
    end)
  end
end
