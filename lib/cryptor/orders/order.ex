defmodule Cryptor.Orders.Order do
  @moduledoc """
   Trader Order
  """
  use Ecto.Schema
  import Ecto.Changeset

  @orders_statuses %{
    "4" => :filled,
    "3" => :canceled
  }

  @required_fields [:order_id, :coin, :quantity, :price, :type]

  @fields @required_fields ++ [:finished, :fee]

  schema "orders" do
    field :order_id, :integer
    field :coin, :string
    field :quantity, :float, default: 0.0
    field :price, :float
    field :type, :string
    field :fee, :string
    field :finished, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs),
    do:
      order
      |> cast(attrs, @fields)
      |> validate_required(@required_fields)

  def mapped_order_statuses(), do: @orders_statuses
end
