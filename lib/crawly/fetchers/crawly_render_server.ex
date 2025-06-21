defmodule Crawly.Fetchers.CrawlyRenderServer do
  @moduledoc """
  Implements Crawly.Fetchers.Fetcher behavior for Crawly Render Server
  JavaScript rendering using Req and built-in JSON.

  Crawly Render Server is a lightweight puppeteer based JavaScript rendering
  engine server. See more: https://github.com/elixir-crawly/crawly-render-server

  It exposes a /render endpoint that renders JS on incoming requests.

  To use this fetcher, configure it in your spider:
  `fetcher: {Crawly.Fetchers.CrawlyRenderServer, [base_url: "http://localhost:3000/render"]}`
  """
  @behaviour Crawly.Fetchers.Fetcher

  require Logger

  @impl Crawly.Fetchers.Fetcher
  def fetch(request, client_options) do
    base_url =
      case Keyword.get(client_options, :base_url) do
        nil ->
          Logger.error(
            "The :base_url is not set. CrawlyRenderServer can't be used! " <>
              "Please set :base_url in fetcher options to continue. " <>
              "For example: " <>
              "fetcher: {Crawly.Fetchers.CrawlyRenderServer, [base_url: <url>]}"
          )

          raise "CrawlyRenderServer fetcher requires a :base_url option"

        url ->
          url
      end

    # 1. Use built-in JSON to encode the request body
    req_body =
      JSON.encode!(%{
        url: request.url,
        headers: Map.new(request.headers)
      })

    # 2. Use Req to make the POST request.
    # We pass the request.options directly to Req, which will use any
    # compatible options (like timeouts).
    case Req.post(
           base_url,
           [body: req_body, headers: %{"content-type" => "application/json"}] ++
             request.options
         ) do
      {:ok, response} ->
        # 3. Use a `with` statement for safer decoding and map access
        with {:ok, js_map} <- JSON.decode(response.body),
             %{"page" => page, "status" => status, "headers" => headers} <-
               js_map do
          # 4. Construct a plain map for the response, which is more idiomatic
          #    and decouples us from any specific HTTP client's response struct.
          #    Crawly's fetcher behavior just needs a struct/map with these keys.
          new_response = %{
            body: page,
            status_code: status,
            headers: headers,
            request_url: request.url,
            request: request
          }

          {:ok, new_response}
        else
          # Handle cases where JSON decoding fails or keys are missing
          _error ->
            {:error,
             %{
               reason: "invalid_response_from_render_server",
               body: response.body
             }}
        end

      # Pass through any request-level errors (e.g., connection refused)
      {:error, _reason} = err ->
        err
    end
  end
end
