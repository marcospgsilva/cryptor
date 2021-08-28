defmodule CryptorWeb.AnalysisController do
  use CryptorWeb, :controller

  def index(conn, _params) do
    %{pid_list: pid_list, order_list: order_list} = :sys.get_state(TradeServer)
    render(conn, "analysis.json", %{analysis: %{pid_list: pid_list, order_list: order_list}})
  end
end
