defmodule Cryptor.Requests do
  @moduledoc """
   Requests
  """
  alias Cryptor.Utils

  def request(method, trade_body, user_id \\ nil)

  def request(:post = method, trade_body, user_id) do
    body = build_body(trade_body)
    headers = get_headers(body, user_id)
    url = get_trade_api_base_url()

    Task.async(__MODULE__, :http_request, [method, url, headers, body])
    |> Task.await(Utils.get_timeout())
    |> handle_response()
  end

  def request(:get = method, path, _user_id) do
    url = get_data_api_base_url(path)

    Task.async(__MODULE__, :http_request, [method, url])
    |> Task.await(Utils.get_timeout())
    |> handle_get_response()
  end

  def http_request(method, url, headers \\ [], body \\ ""),
    do:
      %HTTPoison.Request{
        method: method,
        url: url,
        headers: headers,
        body: body,
        options: get_request_options()
      }
      |> HTTPoison.request()

  def handle_get_response({:ok, %HTTPoison.Response{body: body}}) do
    case Jason.decode(body) do
      {:ok, _body} = response -> response
      _ = error -> error
    end
  end

  def handle_get_response(_), do: {:error, :unexpected_response}

  def handle_response({:ok, %HTTPoison.Response{body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"error_message" => error_message}} ->
        {:error, error_message}

      {:ok, %{"response_data" => _}} = response ->
        response

      {:error, _reason} = error ->
        error
    end
  end

  def handle_response(_response), do: {:error, :unexpected_response}

  def get_headers(body, user_id) do
    tapi_mac = "/tapi/v3/" <> "?#{body}"

    {_, shared_key, api_id} = get_api_keys(user_id) |> List.first()

    crypto =
      :crypto.mac(:hmac, :sha512, shared_key, tapi_mac)
      |> Base.encode16(padding: false)
      |> String.downcase()

    [
      "Content-Type": "application/x-www-form-urlencoded",
      "TAPI-ID": api_id,
      "TAPI-MAC": crypto
    ]
  end

  defp build_body(trade_body),
    do:
      trade_body
      |> Map.put(:tapi_nonce, Utils.get_date_time())
      |> URI.encode_query()

  def get_api_keys(user_id), do: :ets.lookup(:api_keys, user_id)

  def get_data_api_base_url(path),
    do: Application.get_env(:cryptor, Cryptor.Requests)[:data_api_base_url] <> path

  def get_trade_api_base_url,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:trade_api_base_url]

  def get_request_options,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:options]
end
