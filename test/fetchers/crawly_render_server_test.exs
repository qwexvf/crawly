defmodule Crawly.Fetchers.CrawlyRenderServerTest do
  use ExUnit.Case

  alias Crawly.Fetchers.CrawlyRenderServer

  test "raises an error when base_url is not set" do
    request = %Crawly.Request{
      url: "https://example.com",
      headers: %{"User-Agent" => "Custom User Agent"}
    }

    client_options = []

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        # 1. The refactored code now raises a string, not a RuntimeError struct.
        assert_raise RuntimeError,
                     "CrawlyRenderServer fetcher requires a :base_url option",
                     fn ->
                       CrawlyRenderServer.fetch(request, client_options)
                     end
      end)

    assert log =~
             "The :base_url is not set. CrawlyRenderServer can't be used! Please set :base_url"
  end

  test "composes correct request to render server" do
    request = %Crawly.Request{
      url: "https://example.com",
      headers: [{"User-Agent", "Custom User Agent"}],
      options: []
    }

    client_options = [base_url: "http://localhost:3000"]

    # 3. Mock Req.post/2 instead of HTTPoison.post/5
    :meck.expect(Req, :post, fn base_url, options ->
      # 4. Extract headers and body from the options keyword list
      headers = Keyword.get(options, :headers)
      body = Keyword.get(options, :body)

      # 5. Assert against Req's preferred data structures (map for headers)
      assert headers == %{"content-type" => "application/json"}
      assert base_url == "http://localhost:3000"

      decoded_body = JSON.decode!(body)
      assert "https://example.com" == decoded_body["url"]
      assert %{"User-Agent" => "Custom User Agent"} == decoded_body["headers"]

      # Return a mock success tuple to satisfy the function call
      {:ok, %Req.Response{status: 200, body: "{}"}}
    end)

    CrawlyRenderServer.fetch(request, client_options)
  end
end
