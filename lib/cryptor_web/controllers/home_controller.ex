defmodule CryptorWeb.HomeController do
  use CryptorWeb, :controller

  def index(conn, _params) do
    render(conn, "home.html")
  end

  def new(conn, params), do: index(conn, params)
end
