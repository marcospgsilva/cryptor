defmodule Cryptor.Requests do
  @moduledoc """
   Requests
  """
  alias Cryptor.Utils

  def request(method, endpoint, trade_body, user_id \\ nil)

  def request(method, endpoint, body, user_id) do
    {_, shared_key, api_id} = get_api_keys(user_id) |> List.first()

    timestamp = Utils.get_date_time()

    totalParams =
      body
      |> Map.put(:timestamp, timestamp)
      |> Map.put(:recvWindow, 15000)
      |> URI.encode_query()

    signature =
      :crypto.mac(:hmac, :sha256, shared_key, totalParams)
      |> Base.encode16()
      |> String.downcase()

    body =
      case method do
        :get ->
          body
          |> Map.put(:timestamp, timestamp)
          |> Map.put(:recvWindow, 15000)
          |> URI.encode_query()

        _ ->
          body
          |> Map.put(:timestamp, timestamp)
          |> Map.put(:recvWindow, 15000)
          |> Map.put(:signature, signature)
          |> URI.encode_query()
      end

    url = get_url(method, endpoint, body, signature)

    Task.async(__MODULE__, :http_request, [
      method,
      url,
      ["X-MBX-APIKEY": api_id],
      if(method == :get, do: "", else: body)
    ])
    |> Task.await(Utils.get_timeout())
    |> handle_response()
  end

  def get_url(:get, endpoint, body, signature),
    do: get_trade_api_base_url(endpoint) <> "?#{body}&signature=#{signature}"

  def get_url(_, endpoint, _body, _signature), do: get_trade_api_base_url(endpoint)

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

  def handle_response({:ok, %HTTPoison.Response{body: body}}) do
    case Jason.decode(body) do
      {:ok, %{"msg" => msg} = response} ->
        IO.inspect(response)
        {:error, msg}

      {:ok, resp} = response ->
        IO.inspect(resp)
        response

      {:error, reason} = error ->
        IO.inspect(reason)
        error
    end
  end

  def handle_response(_response), do: {:error, :unexpected_response}

  def get_api_keys(user_id), do: :ets.lookup(:api_keys, user_id)

  def get_trade_api_base_url(path),
    do: Application.get_env(:cryptor, Cryptor.Requests)[:trade_api_base_url_v2] <> path

  def get_request_options,
    do: Application.get_env(:cryptor, Cryptor.Requests)[:options]
end
