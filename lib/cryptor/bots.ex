defmodule Cryptor.Bots do
  import Ecto.Query

  alias Cryptor.Bots.Bot
  alias Cryptor.Repo

  def get_bot(user_id, currency) do
    from(
      bot in Bot,
      where:
        bot.user_id == ^user_id and
          bot.currency == ^currency
    )
    |> Repo.one()
  end

  def create_bot(attrs) do
    %Bot{}
    |> Bot.changeset(attrs)
    |> Repo.insert()
  end

  def build_bots(currencies) do
    Enum.map(currencies, &%{currency: &1})
  end

  def update_bot(bot, attrs) do
    bot
    |> Bot.changeset(attrs)
    |> Repo.update()
  end
end
