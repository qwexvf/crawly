defmodule CrawlyTest do
  use ExUnit.Case

  describe "fetch/2" do
    test "can fetch a given url" do
      # 1. Mock the fetcher, not the HTTP client
      :meck.expect(Crawly.Fetchers.ReqFetcher, :fetch, fn _request, _options ->
        # 2. Return the standardized map
        {:ok, %{status_code: 200, body: "ok"}}
      end)

      # 3. Assert against the map structure
      assert {:ok, %{status_code: 200}} = Crawly.fetch("https://example.com")
    end

    test "returns error if unable to fetch the page" do
      :meck.expect(Crawly.Fetchers.ReqFetcher, :fetch, fn _request, _options ->
        # 4. Return a Req error struct
        {:error, %Req.TransportError{reason: :nxdomain}}
      end)

      assert {:error, %Req.TransportError{reason: :nxdomain}} =
               Crawly.fetch("invalid-url")
    end

    test "can fetch a given url with custom request options" do
      request_opts = [timeout: 5000, recv_timeout: 5000]

      # The `fetch` function passes `request_opts` as the second argument to the fetcher
      :meck.expect(Crawly.Fetchers.ReqFetcher, :fetch, fn _request,
                                                          passed_request_opts ->
        assert passed_request_opts == request_opts
        {:ok, %{status_code: 200}}
      end)

      assert {:ok, %{}} =
               Crawly.fetch("https://example.com", request_opts: request_opts)
    end

    test "can fetch a given url with headers" do
      headers = [{"Authorization", "Bearer token"}]

      # The headers are inside the `request` struct passed as the first argument
      :meck.expect(Crawly.Fetchers.ReqFetcher, :fetch, fn request, _options ->
        assert request.headers == headers
        {:ok, %{status_code: 200}}
      end)

      assert {:ok, %{}} =
               Crawly.fetch("https://example.com", headers: headers)
    end
  end

  describe "fetch_with_spider/3" do
    test "Can fetch a given url from behalf of the spider" do
      expected_new_requests = [
        Crawly.Utils.request_from_url("https://www.example.com")
      ]

      # Mock the fetcher to return a successful response map
      :meck.expect(Crawly.Fetchers.ReqFetcher, :fetch, fn _request, _options ->
        {:ok, %{status_code: 200, body: "<html>...</html>"}}
      end)

      :meck.new(CrawlyTestSpider, [:non_strict])

      # The spider's parse_item will receive the map from the fetcher
      :meck.expect(CrawlyTestSpider, :parse_item, fn response ->
        # Assert that the spider receives the correct map structure
        assert response.status_code == 200

        %{
          items: [%{content: "hello"}],
          requests: expected_new_requests
        }
      end)

      %{requests: requests, items: items} =
        Crawly.fetch_with_spider("https://example.com", CrawlyTestSpider)

      assert items == [%{content: "hello"}]
      assert requests == expected_new_requests
    end
  end
end
