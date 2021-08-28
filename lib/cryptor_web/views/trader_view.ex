defmodule CryptorWeb.TraderView do
  use CryptorWeb, :view

  @currencies ["LTC", "XRP", "ETH", "USDC", "AXS", "BAT", "ENJ", "CHZ", "BRL"]

  def render("trader.json", %{trader: %{account_info: account_info}}) do
    %{
      infos: treat_account_info(account_info)
    }
  end

  def treat_account_info(nil), do: nil

  def treat_account_info(account_info),
    do:
      @currencies
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

  def render_info(moeda, pedidos_em_aberto, quantidade_disponível, quantidade) do
    %{
      moeda: moeda,
      pedidos_em_aberto: pedidos_em_aberto,
      quantidade_disponível: quantidade_disponível,
      quantidade: quantidade
    }
  end
end
