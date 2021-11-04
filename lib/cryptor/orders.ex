defmodule Cryptor.Orders do
  import Ecto.Query
  alias Cryptor.Repo
  alias Cryptor.Orders.Order
  alias Cryptor.Accounts.User

  def get_order(id) do
    Repo.one(
      from order in Order,
        where: order.order_id == ^id
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

  def get_orders() do
    Repo.all(
      from order in Order,
        where:
          order.finished == false and
            order.type == "buy",
        order_by: [desc: order.id]
    )
  end

  def get_orders(user_id) do
    Repo.all(
      from order in Order,
        join: user in User,
        where:
          order.finished == false and
            order.type == "buy" and
            order.user_id == ^user_id,
        order_by: [desc: order.id]
    )
  end

  def get_latest_sell_orders(currency) do
    Repo.all(
      from order in Order,
        where:
          order.coin == ^currency and
            order.type == "sell",
        order_by: [desc: order.inserted_at]
    )
  end
end
