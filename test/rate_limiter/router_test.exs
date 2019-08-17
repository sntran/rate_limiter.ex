defmodule RateLimiter.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest RateLimiter.Router

  alias RateLimiter.Router

  @opts Router.init([])

  test "returns 200" do
    # Create a test connection
    conn = conn(:get, "/receive-message")

    # Invoke the plug
    conn = Router.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 200
  end

  test "returns 404 for any other routes" do
    # Create a test connection
    conn = conn(:post, "/receive-message")

    # Invoke the plug
    conn = Router.call(conn, @opts)

    assert conn.state == :sent
    assert conn.status == 404

    conn = conn(:get, "/hello")
    conn = Router.call(conn, @opts)
    assert conn.status == 404
  end
end
