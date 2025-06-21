defmodule Crawly.Fetchers.ReqFetcher do
  @moduledoc """
  Implements Crawly.Fetchers.Fetcher behavior based on the Req HTTP client.
  This is a modern, recommended default fetcher.
  """
  @behaviour Crawly.Fetchers.Fetcher

  require Logger

  @impl Crawly.Fetchers.Fetcher
  def fetch(request, _client_options) do
    # Req.get/2 takes the URL and a keyword list of options.
    # We can pass the headers and options from the Crawly request directly.
    Req.get(request.url,
      headers: request.headers,
      connect_options: request.options
    )
  end
end
