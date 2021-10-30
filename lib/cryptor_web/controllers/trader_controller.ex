defmodule CryptorWeb.TraderController do
  use CryptorWeb, :controller

  def index(conn, _params) do
    render(conn, "trader.json", %{})
  end
end
