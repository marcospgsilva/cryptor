defmodule Cryptor.CurrencySocket do
  use WebSockex

  def start_link(%{currency: currency}) do
    downcase_currency = String.downcase(currency)

    WebSockex.start_link(
      get_data_api_base_url("/#{downcase_currency}brl@ticker"),
      __MODULE__,
      %{currency: currency},
      name: String.to_atom(currency <> "Server")
    )
  end

  def get_current_price(currency),
    do:
      Cryptor.CurrencyAgent.get_currency_prices()
      |> Map.get(currency, 0.0)

  @impl true
  def handle_frame({_type, msg}, %{currency: currency} = state) do
    case Jason.decode(msg) do
      {:ok, currency_data} ->
        Cryptor.CurrencyAgent.update_currency_price({currency, currency_data["c"]})
        Process.sleep(5000)
        {:ok, state}

      {:error, _} ->
        {:ok, state}
    end
  end

  def get_data_api_base_url(path),
    do: Application.get_env(:cryptor, Cryptor.Requests)[:data_api_base_url_v2] <> path
end
