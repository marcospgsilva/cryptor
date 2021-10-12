defmodule CryptorWeb.AnalysisController do
  use CryptorWeb, :controller
  alias Cryptor.Orders.OrdersAgent
  alias Cryptor.Trader.TradeServer

  def index(conn, _params) do
    %{pid_list: pid_list} = TradeServer.get_state()
    order_list = OrdersAgent.get_order_list()

    render(conn, "analysis.json", %{analysis: %{pid_list: pid_list, order_list: order_list}})
  end
end
