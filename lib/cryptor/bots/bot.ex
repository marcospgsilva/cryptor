defmodule Cryptor.Bots.Bot do
  @moduledoc """
   Cryptor Bot
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:currency]

  @fields [
            :sell_percentage_limit,
            :buy_percentage_limit,
            :sell_amount,
            :buy_amount,
            :user_id,
            :active,
            :max_orders_amount,
            :sell_active,
            :buy_active
          ] ++ @required_fields

  @default_sell_percentage_limit 1.008
  @default_buy_percentage_limit 0.985
  @default_sell_amount 1.0
  @default_buy_amount 1.0
  @default_max_orders_amount 1

  schema "bots" do
    field :currency, :string
    field :sell_percentage_limit, :float, default: @default_sell_percentage_limit
    field :buy_percentage_limit, :float, default: @default_buy_percentage_limit
    field :sell_amount, :float, default: @default_sell_amount
    field :buy_amount, :float, default: @default_buy_amount
    field :active, :boolean, default: false
    field :buy_active, :boolean, default: false
    field :sell_active, :boolean, default: false
    field :max_orders_amount, :integer, default: @default_max_orders_amount
    belongs_to :user, Cryptor.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(currency, attrs),
    do:
      currency
      |> cast(attrs, @fields)
      |> validate_required(@required_fields)
      |> assoc_constraint(:user)
end
