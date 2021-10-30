defmodule CryptorWeb.TraderView do
  use CryptorWeb, :view

  def render("trader.json", trader_data), do: trader_data
end
