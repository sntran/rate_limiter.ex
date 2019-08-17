# RateLimiter

This Elixir application accepts messages via an HTTP endpoint and processes the messages in the order that they are received, and no more than one per second. The application should be able to handle multiple queues based on a parameter passed into the HTTP endpoint.

1. [x] The application is a simple Plug based web server.
2. [x] The application has an HTTP endpoint at the path `/receive-message` which accepts a GET request with the query string parameters: `queue` (string), `message` (string).
3. [x] The application will accept messages as quickly as they come in and return a 200 status code.
4. [ ] The application will "process" the messages by printing the message text to the terminal, however for each queue, the application should only "process" one message a second, no matter how quickly the messages are submitted to the HTTP endpoint.
5. [ ] Tests that verifies messages are only processed one per second.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rate_limiter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rate_limiter, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/rate_limiter](https://hexdocs.pm/rate_limiter).

