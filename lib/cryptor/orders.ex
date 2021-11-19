defmodule Cryptor.Orders do
  import Ecto.Query
  alias Cryptor.Repo
  alias Cryptor.Orders.Order
  alias Cryptor.Accounts.User

  def get_order(id, user_id) do
    Repo.one(
      from order in Order,
        join: user in User,
        where:
          order.order_id == ^id and
            user.id == ^user_id
    )
  end

  def create_order(attrs),
    do:
      %Order{}
      |> Order.changeset(attrs)
      |> Repo.insert()
      |> elem(1)

  def update_order(order, attrs),
    do:
      order
      |> Order.changeset(attrs)
      |> Repo.update()

  def get_orders(user_id) do
    Repo.all(
      from order in Order,
        join: user in User,
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
        join: user in User,
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
        join: user in User,
        where:
          order.filled == false and
            order.user_id == ^user_id,
        order_by: [desc: order.inserted_at]
    )
  end
end
