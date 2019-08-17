defmodule RateLimiter.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/receive-message" do
    send_resp(conn, 200, "ack")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end