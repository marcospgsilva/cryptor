defmodule Cryptor.Order do
  @moduledoc """
   Trader Order
  """
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias Cryptor.Repo
  alias __MODULE__

  @required_fields [:order_id, :coin, :quantity, :price, :type]

  @fields @required_fields ++ [:finished]

  schema "orders" do
    field :order_id, :integer
    field :coin, :string
    field :quantity, :float
    field :price, :float
    field :type, :string
    field :finished, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs) do
    order
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def get_order(id) do
    Repo.one(
      from order in Order,
      where: order.id == ^id
    )
  end

  def create_order(attrs),
    do:
      %__MODULE__{}
      |> changeset(attrs)
      |> Repo.insert()
      |> elem(1)

  def update_order(nil, _attrs), do: nil

  def update_order(order, attrs) do
    order
    |> changeset(attrs)
    |> Repo.update()
  end

  def get_orders() do
    Repo.all(
      from order in Order,
        where: order.finished == false,
        order_by: [desc: order.id]
    )
  end
end
