defmodule CryptorWeb.TraderController do
  use CryptorWeb, :controller

  def index(conn, _params) do
    %{account_info: account_info} = :sys.get_state(TradeServer)
    render(conn, "trader.json", %{trader: %{account_info: account_info}})
  end
end
