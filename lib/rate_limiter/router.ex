defmodule RateLimiter.Router do
  import Plug.Conn
  use Plug.Router

  plug :match
  plug :dispatch

  get "/receive-message" do
    conn = fetch_query_params(conn)
    case conn.query_params do
      %{"message" => message, "queue" => queue} ->
        worker = fn(_) ->
          IO.puts message
        end
        RateLimiter.enqueue({worker, queue})
      _params ->
        :skip
    end
    
    send_resp(conn, 200, "ack")
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end