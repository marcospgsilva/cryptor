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

  schema "bots" do
    field :currency, :string
    field :sell_percentage_limit, :float, default: 1.008
    field :buy_percentage_limit, :float, default: 0.985
    field :sell_amount, :float, default: 1.0
    field :buy_amount, :float, default: 1.0
    field :active, :boolean, default: false
    field :buy_active, :boolean, default: false
    field :sell_active, :boolean, default: false
    field :max_orders_amount, :integer, default: 1
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
