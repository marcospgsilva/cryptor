defmodule Cryptor.Requests do
  @moduledoc """
   Requests
  """
  alias Cryptor.Utils

  @default_request_options [timeout: :infinity, recv_timeout: :infinity]

  def request(:get, path),
    do:
      get_data_api_base_url(path)
      |> HTTPoison.get(@default_request_options)
      |> handle_get_response()

  def request(:post, trade_body) do
    body =
      trade_body
      |> Map.put(:tapi_nonce, Utils.get_date_time())
      |> URI.encode_query()

    headers = get_headers(body)

    case trade_body do
      %{tapi_method: "get_account_info"} ->
        nil

      _ ->
        IO.inspect(body)
    end

    get_trade_api_base_url()
    |> HTTPoison.post(body, headers, @default_request_options)
    |> handle_response()
  end

  def handle_get_response({:ok, %HTTPoison.Response{body: body}}) do
    case Jason.decode(body) do
      {:ok, _body} = response -> response
      _ -> nil
    end
  end

  def handle_get_response(_), do: nil

  def handle_response({:ok, %HTTPoison.Response{status_code: 100, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"response_data" => %{"balance" => _balances}}} = response ->
        response

      {:ok, _} = response ->
        IO.inspect(response)

      {:error, reason} ->
        IO.inspect(reason)
        nil
    end
  end

  def handle_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"response_data" => %{"balance" => _balances}}} = response ->
        response

      {:ok, _} = response ->
        IO.inspect(response)

      {:error, reason} ->
        IO.inspect(reason)
        nil
    end
  end

  def handle_response(_ = response) do
    IO.inspect(response)
    nil
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

  def get_tapi_id,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:tapi_id]

  def get_tapi_id_secret_key,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:tapi_id_secret_key]

  def get_data_api_base_url(path),
    do: Application.get_env(:cryptor, Cryptor.Requests)[:data_api_base_url] <> path

  def get_trade_api_base_url,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:trade_api_base_url]
end
