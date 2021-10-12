defmodule CryptorWeb.TraderView do
  use CryptorWeb, :view
  alias Cryptor.Trader.TradeServer

  def render("trader.json", %{trader: %{account_info: account_info}}),
    do: %{
      infos: treat_account_info(account_info)
    }

  def treat_account_info(nil), do: nil

  def treat_account_info(account_info),
    do:
      (TradeServer.get_currencies() ++ ["BRL"])
      |> Enum.map(&treat_account_info(&1, account_info))

  def treat_account_info("BRL" = currency, account_info) do
    %{
      "available" => available,
      "total" => quantity
    } = account_info["response_data"]["balance"][String.downcase(currency)]

    render_info(currency, 0, available, quantity)
  end

  def treat_account_info(currency, account_info) do
    %{
      "amount_open_orders" => amount_open_orders,
      "available" => available,
      "total" => quantity
    } = account_info["response_data"]["balance"][String.downcase(currency)]

    render_info(currency, amount_open_orders, available, quantity)
  end

  def render_info(currency, open_orders, avaiable_amount, amount),
    do: %{
      moeda: currency,
      pedidos_em_aberto: open_orders,
      quantidade_disponível: avaiable_amount,
      quantidade: amount
    }
end
