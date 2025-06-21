defmodule Pipelines.JSONEncoderTest do
  use ExUnit.Case, async: false

  @valid %{data: [%{some: "nested_data"}]}

  test "Converts a given map to a json string" do
    pipelines = [Crawly.Pipelines.JSONEncoder]
    item = @valid
    state = %{spider_name: Test, crawl_id: "test"}

    {json_string, _state} = Crawly.Utils.pipe(pipelines, item, state)

    assert is_binary(json_string)
    assert json_string =~ @valid.data |> hd() |> Map.get(:some)
    assert json_string =~ "data"
    assert json_string =~ "some"
  end
end
