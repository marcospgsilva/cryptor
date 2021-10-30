defmodule CryptorWeb.AnalysisController do
  use CryptorWeb, :controller

  def index(conn, _params) do
    render(conn, "analysis.json", %{})
  end
end
