defmodule UtilsTest do
  use ExUnit.Case, async: false
  require Req

  setup do
    on_exit(fn ->
      System.delete_env("SPIDERS_DIR")
      :ok = Crawly.Utils.clear_registered_spiders()
      :meck.unload()
    end)

    :ok
  end

  test "Request from url" do
    requests = Crawly.Utils.request_from_url("https://test.com")
    assert requests == expected_request("https://test.com")
  end

  test "Requests from urls" do
    requests =
      Crawly.Utils.requests_from_urls([
        "https://test.com",
        "https://example.com"
      ])

    assert requests == [
             expected_request("https://test.com"),
             expected_request("https://example.com")
           ]
  end

  test "Build absolute url test" do
    url = Crawly.Utils.build_absolute_url("/url1", "http://example.com")
    assert url == "http://example.com/url1"
  end

  test "Build absolute urls test" do
    paths = ["/path1", "/path2"]
    result = Crawly.Utils.build_absolute_urls(paths, "http://example.com")

    assert result == ["http://example.com/path1", "http://example.com/path2"]
  end

  test "pipe with args" do
    :meck.new(FakePipeline, [:non_strict])

    :meck.expect(
      FakePipeline,
      :run,
      fn item, state, args ->
        {item, Map.put(state, :args, args)}
      end
    )

    :meck.expect(
      FakePipeline,
      :run,
      fn item, state ->
        {item, state}
      end
    )

    {_item, state} =
      Crawly.Utils.pipe([{FakePipeline, my: "arg"}], %{my: "item"}, %{})

    assert state.args == [my: "arg"]
  end

  test "pipe without args" do
    :meck.new(FakePipeline, [:non_strict])

    :meck.expect(
      FakePipeline,
      :run,
      fn item, state, args ->
        {item, %{state | args: args}}
      end
    )

    :meck.expect(
      FakePipeline,
      :run,
      fn item, state ->
        {item, state}
      end
    )

    {_item, state} = Crawly.Utils.pipe([FakePipeline], %{my: "item"}, %{})

    assert Map.has_key?(state, :args) == false
  end

  test "can find CrawlySpider behaviors" do
    assert Enum.any?(
             Crawly.Utils.list_spiders(),
             fn x -> x == UtilsTestSpider end
           )
  end

  test "Can load modules set in SPIDERS_DIR" do
    System.put_env("SPIDERS_DIR", "./examples/quickstart/lib/quickstart")
    {:ok, loaded_modules} = Crawly.Utils.load_spiders()

    assert Enum.sort([Quickstart.Application, BooksToScrape]) ==
             Enum.sort(loaded_modules)
  end

  test "Invalid module options format" do
    :meck.expect(
      Crawly.Utils,
      :get_settings,
      fn :fetcher, nil, nil ->
        {Crawly.Fetchers.ReqFetcher}
      end
    )

    assert catch_error(
             Crawly.Utils.get_settings(:fetcher, nil, nil)
             |> Crawly.Utils.unwrap_module_and_options()
           )
  end

  test "extract_requests Can extract requests from a given HTML document" do
    html = """
    <!doctype html>
      <html>
      <body>
        <a class="link" href="/philss/floki">Github page</a>
      </body>
      </html>
    """

    {:ok, document} = Floki.parse_document(html)

    # 1. Replaced Poison with built-in JSON
    selectors =
      JSON.encode!([%{"selector" => "a.link", "attribute" => "href"}])

    [request] =
      Crawly.Utils.extract_requests(document, selectors, "https://github.com")

    assert "https://github.com/philss/floki" == request.url
  end

  test "extract_requests work with multiple selectors" do
    html = """
    <!doctype html>
      <html>
      <body>
        <a class="link" href="/philss/floki">Github page</a>
        <a class="hex" href="https://hex.pm/packages/floki">Hex package</a>
      </body>
      </html>
    """

    {:ok, document} = Floki.parse_document(html)

    # 2. Replaced Poison with built-in JSON
    selectors =
      JSON.encode!([
        %{"selector" => "a.hex", "attribute" => "href"},
        %{"selector" => "a.link", "attribute" => "href"}
      ])

    extracted_urls =
      Enum.map(
        Crawly.Utils.extract_requests(
          document,
          selectors,
          "https://github.com"
        ),
        fn request -> request.url end
      )

    expected_urls = [
      "https://github.com/philss/floki",
      "https://hex.pm/packages/floki"
    ]

    assert Enum.sort(expected_urls) == Enum.sort(extracted_urls)
  end

  test "extract_items Can extract items from a given document" do
    html = """
    <!doctype html>
      <html>
      <body>
        <p class="headline">Floki</p>
        <span class="body">Enables search using CSS selectors</span>
      </body>
      </html>
    """

    {:ok, document} = Floki.parse_document(html)

    # 3. Replaced Poison with built-in JSON
    selectors =
      JSON.encode!([
        %{"selector" => ".headline", "name" => "title"},
        %{"selector" => "span.body", "name" => "body"}
      ])

    [item] = Crawly.Utils.extract_items(document, selectors)

    assert "Floki" == Map.get(item, "title")
    assert "Enables search using CSS selectors" == Map.get(item, "body")
  end

  @compile {:no_warn_undefined, BooksSpiderForTest}
  test "Can load a spider from a YML format" do
    _spider_yml = """
    ...
    """

    # ...
  end

  test "returns log path with expected format" do
    path = Crawly.Utils.spider_log_path(:spider, "123")
    assert path == Path.join(["/tmp/spider_logs", "spider", "123"]) <> ".log"
  end

  # ... (other log path tests are fine)

  test "returns an error when given invalid YAML code" do
    yml = "invalid_yaml"
    result = Crawly.Utils.preview(yml)
    assert length(result) == 1
    message = hd(result)
    assert message.error =~ "Nothing can be extracted from YML code"
  end

  test "can handle http connection errors" do
    yml = """
    ---
    name: BooksSpiderForTest
    base_url: "https://books.toscrape.com/"
    start_urls: ["https://books.toscrape.com/"]
    fields: []
    links_to_follow: []
    """

    :meck.expect(
      Req,
      :get,
      fn _url ->
        {:error, %Req.TransportError{reason: :nxdomain}}
      end
    )

    [result] = Crawly.Utils.preview(yml)
    # 6. Assert against the new error struct's string representation
    assert result.error =~ "%Req.TransportError{reason: :nxdomain}"
  end

  test "can extract data from given page" do
    wtf = """
    <h1> My product </h1>
    <a href="/next"></a>
    """

    yml = """
    ---
    name: BooksSpiderForTest
    base_url: "https://books.toscrape.com/"
    start_urls: ["https://books.toscrape.com/"]
    fields:
      - name: title
        selector: "h1"
    links_to_follow:
      - selector: "a"
        attribute: "href"
    """

    :meck.expect(
      Req,
      :get,
      fn _url ->
        {:ok, %Req.Response{body: wtf, status: 200}}
      end
    )

    [result] = Crawly.Utils.preview(yml)

    assert result.items == [%{"title" => " My product "}]
    assert result.requests == ["https://books.toscrape.com/next"]
    assert result.url == "https://books.toscrape.com/"
  end

  defp expected_request(url) do
    %Crawly.Request{
      url: url,
      headers: [],
      options: [],
      middlewares: [
        Crawly.Middlewares.DomainFilter,
        Crawly.Middlewares.UniqueRequest,
        Crawly.Middlewares.RobotsTxt,
        {Crawly.Middlewares.UserAgent, user_agents: ["My Custom Bot"]}
      ],
      retries: 0
    }
  end
end
