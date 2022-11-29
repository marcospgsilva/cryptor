defmodule Cryptor.Orders do
  import Ecto.Query
  alias Cryptor.Repo
  alias Cryptor.Orders.Order

  def get_order(id, user_id) do
    Repo.one(
      from order in Order,
        where:
          order.order_id == ^id and
            order.user_id == ^user_id
    )
  end

  def create_order(attrs) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
    |> elem(1)
  end

  def update_order(order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  def get_orders(user_id) do
    Repo.all(
      from order in Order,
        where:
          order.finished == false and
            order.filled == true and
            order.type == "buy" and
            order.user_id == ^user_id,
        order_by: [desc: order.inserted_at]
    )
  end

  def get_latest_sell_orders(currency, user_id) do
    Repo.all(
      from order in Order,
        where:
          order.user_id == ^user_id and
            order.type == "sell" and
            order.filled == true and
            order.coin == ^currency,
        order_by: [desc: order.updated_at]
    )
  end

  def get_pending_orders(user_id) do
    Repo.all(
      from order in Order,
        where:
          order.filled == false and
            order.user_id == ^user_id,
        order_by: [desc: order.inserted_at]
    )
  end
end
