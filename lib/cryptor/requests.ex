defmodule Cryptor.Requests do
  @moduledoc """
   Requests
  """
  alias Cryptor.Utils

  def request(:get = method, path) do
    url = get_data_api_base_url(path)

    http_request(method, url)
    |> handle_get_response()
  end

  def request(:post = method, trade_body) do
    body = build_body(trade_body)
    headers = get_headers(body)
    url = get_trade_api_base_url()

    case trade_body do
      %{tapi_method: "get_account_info"} ->
        nil

      _ ->
        IO.inspect(body)
    end

    http_request(method, url, headers, body)
    |> handle_response()
  end

  def http_request(method, url, headers \\ [], body \\ "") do
    %HTTPoison.Request{
      method: method,
      url: url,
      headers: headers,
      body: body,
      options: get_request_options()
    }
    |> HTTPoison.request()
  end

  def handle_get_response({:ok, %HTTPoison.Response{body: body}}) do
    case Jason.decode(body) do
      {:ok, _body} = response -> response
      _ = error -> error
    end
  end

  def handle_get_response(_), do: {:error, :unexpected_response}

  def handle_response({:ok, %HTTPoison.Response{status_code: 100, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"response_data" => %{"balance" => _balances}}} = response ->
        response

      {:ok, _} = response ->
        IO.inspect(response)
        response

      {:error, reason} = error ->
        IO.inspect(reason)
        error
    end
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"response_data" => %{"balance" => _balances}}} = response ->
        response

      {:ok, _} = response ->
        IO.inspect(response)
        response

      {:error, reason} = error ->
        IO.inspect(reason)
        error
    end
  end

  def handle_response(_ = response) do
    IO.inspect(response)
    {:error, :unexpected_response}
  end

  def get_headers(body) do
    tapi_mac = "/tapi/v3/" <> "?#{body}"
    key = get_tapi_id_secret_key()

    crypto =
      :crypto.mac(:hmac, :sha512, key, tapi_mac)
      |> Base.encode16(padding: false)
      |> String.downcase()

    [
      "Content-Type": "application/x-www-form-urlencoded",
      "TAPI-ID": get_tapi_id(),
      "TAPI-MAC": crypto
    ]
  end

  defp build_body(trade_body),
    do:
      trade_body
      |> Map.put(:tapi_nonce, Utils.get_date_time())
      |> URI.encode_query()

  def get_tapi_id,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:tapi_id]

  def get_tapi_id_secret_key,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:tapi_id_secret_key]

  def get_data_api_base_url(path),
    do: Application.get_env(:cryptor, Cryptor.Requests)[:data_api_base_url] <> path

  def get_trade_api_base_url,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:trade_api_base_url]

  def get_request_options,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:options]
end
