defmodule Cryptor.Orders.OrdersAgent do
  @moduledoc """
  Orders Agent
  """
  use Agent
  alias Cryptor.Orders

  def start_link(%{name: name, user_id: user_id}),
    do:
      Agent.start_link(
        fn ->
          orders = Orders.get_orders(user_id)
          IO.inspect(user_id, label: "ORDERS AGENT ID")
          IO.inspect(orders, label: "ORDERS AGENT INITIAL")
          orders
        end,
        name: name
      )

  def get_order_list(pid), do: Agent.get(pid, & &1)

  def add_to_order_list(pid, new_order),
    do:
      Agent.update(pid, fn orders ->
        first = orders |> List.first()
        IO.inspect(first.user_id, label: "UPDATE: USER_ID")
        IO.inspect(orders, label: "UPDATE: OLD ORDERS")
        new_state = [new_order | orders]
        IO.inspect(new_state, label: "UPDATE: NEW ORDERS")
        new_state
      end)

  def remove_from_order_list(pid, order_to_be_removed) do
    Agent.update(pid, fn orders ->
      orders
      |> Enum.reject(&(order_to_be_removed.order_id == &1.order_id))
    end)
  end
end
