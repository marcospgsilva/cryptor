defmodule Cryptor.Orders.PendingOrdersAgent do
  @moduledoc """
   Pending Orders Agent
  """
  use Agent

  alias Cryptor.{Orders, ProcessRegistry}

  def start_link(%{name: name, user_id: user_id}) do
    Agent.start_link(fn -> Orders.get_pending_orders(user_id) end, name: name)
  end

  def get_pending_orders_list(pid) do
    Agent.get(pid, & &1)
  end

  def add_to_pending_orders_list(pid, new_order) do
    Agent.update(pid, &[new_order | &1])
  end

  def remove_from_pending_orders_list(user_id, order_to_be_removed) do
    user_id
    |> ProcessRegistry.get_servers_registry()
    |> Map.get(:pending_orders_pid)
    |> Agent.update(fn pending_orders ->
      Enum.reject(pending_orders, &(order_to_be_removed.order_id == &1.order_id))
    end)
  end
end
