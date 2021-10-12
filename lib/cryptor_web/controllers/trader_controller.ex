defmodule CryptorWeb.TraderController do
  use CryptorWeb, :controller
  alias Cryptor.Trader.TradeServer

  def index(conn, _params) do
    %{account_info: account_info} = TradeServer.get_state()
    render(conn, "trader.json", %{trader: %{account_info: account_info}})
  end
end
