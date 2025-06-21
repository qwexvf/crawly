defmodule Crawly.Fetchers.Splash do
  @moduledoc """
  Implements Crawly.Fetchers.Fetcher behavior for Splash Javascript rendering using Req.

  Splash is a lightweight QT based Javascript rendering engine. See:
  https://splash.readthedocs.io/

  This fetcher converts all requests made by Crawly to Splash requests by
  passing the target URL and other options as query parameters.

  To use this fetcher, configure it in your spider:
  `fetcher: {Crawly.Fetchers.Splash, [base_url: "http://localhost:8050/render.html", wait: 0.5]}`
  """
  @behaviour Crawly.Fetchers.Fetcher

  require Logger

  @impl Crawly.Fetchers.Fetcher
  def fetch(request, client_options) do
    # 1. Safely extract the base_url, raising an error if it's missing.
    #    Keyword.pop/2 is perfect here as it separates the base_url from
    #    the other options (like :wait, :timeout) which will become query params.
    {base_url, splash_params} =
      case Keyword.pop(client_options, :base_url) do
        {nil, _} ->
          raise "The :base_url is not set. Splash fetcher can't be used! " <>
                  "Please set :base_url in fetcher options to continue. " <>
                  "For example: " <>
                  "fetcher: {Crawly.Fetchers.Splash, [base_url: <url>]}"

        {url, other_options} ->
          {url, other_options}
      end

    # 2. Add the target URL to the list of Splash query parameters.
    all_params = Keyword.put(splash_params, :url, request.url)

    # 3. Use Req.get, passing the query parameters directly to the :params option.
    #    Req will handle URL encoding automatically.
    case Req.get(base_url,
           params: all_params,
           headers: request.headers,
           connect_options: request.options
         ) do
      {:ok, response} ->
        # 4. Construct a clean response map for Crawly.
        #    Crucially, we use the *original* request.url, not the Splash URL.
        new_response = %{
          body: response.body,
          status_code: response.status,
          headers: response.headers,
          request_url: request.url,
          request: request
        }

        {:ok, new_response}

      # Pass through any request-level errors
      {:error, _reason} = err ->
        err
    end
  end
end
