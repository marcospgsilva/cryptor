defmodule Cryptor.Order do
  @moduledoc """
   Trader Order
  """
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset
  alias Cryptor.Repo
  alias __MODULE__

  @orders_statuses %{
    "4" => :filled,
    "3" => :canceled
  }

  @required_fields [:order_id, :coin, :quantity, :price, :type]

  @fields @required_fields ++ [:finished]

  schema "orders" do
    field :order_id, :integer
    field :coin, :string
    field :quantity, :float, default: 0.0
    field :price, :float
    field :type, :string
    # field :fee, :string
    field :finished, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs),
    do:
      order
      |> cast(attrs, @fields)
      |> validate_required(@required_fields)

  def get_order(id) do
    Repo.one(
      from order in Order,
        where: order.order_id == ^id
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

  def mapped_order_statuses(), do: @orders_statuses
end
