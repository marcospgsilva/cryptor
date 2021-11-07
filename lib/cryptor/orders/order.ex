defmodule Cryptor.Orders.Order do
  @moduledoc """
   Order
  """
  use Ecto.Schema
  import Ecto.Changeset

  @orders_statuses %{
    "4" => :filled,
    "3" => :canceled
  }

  @fields [
    :order_id,
    :coin,
    :quantity,
    :price,
    :type,
    :finished,
    :fee,
    :filled,
    :buy_order_id,
    :user_id
  ]

  schema "orders" do
    field :order_id, :integer
    field :coin, :string
    field :quantity, :float, default: 0.0
    field :price, :float
    field :type, :string
    field :fee, :string
    field :finished, :boolean, default: false
    field :filled, :boolean, default: false
    field :buy_order_id, :integer
    belongs_to :user, Cryptor.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(order, attrs),
    do:
      order
      |> cast(attrs, @fields)
      |> assoc_constraint(:user)

  def mapped_order_statuses(), do: @orders_statuses
end
