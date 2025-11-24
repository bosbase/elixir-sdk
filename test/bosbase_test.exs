defmodule BosbaseTest do
  use ExUnit.Case
  alias Bosbase.Client

  test "creates client with defaults" do
    client = Bosbase.new("http://127.0.0.1:8090", lang: "bg-BG")
    assert %Client{} = client
    assert client.lang == "bg-BG"
    assert client.base_url == "http://127.0.0.1:8090"
  end

  test "filter binds parameters safely" do
    assert "title ~ 'te\\'st'" == Bosbase.filter("title ~ {:title}", %{title: "te'st"})
  end

  test "build_url concatenates path and query" do
    client = Bosbase.new("http://example.com")
    url = Client.build_url(client, "/api/health", %{foo: "bar"})
    assert url == "http://example.com/api/health?foo=bar"
  end
end
