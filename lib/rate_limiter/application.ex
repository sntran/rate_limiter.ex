defmodule RateLimiter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Starts a worker by calling: RateLimiter.Worker.start_link(arg)
      # {RateLimiter.Worker, arg}
      {Plug.Cowboy, scheme: :http, plug: RateLimiter.Router, options: [port: 4000]}
    ]

    children = if Mix.env !== :test do
      [{RateLimiter, []} | children]
    else
      children
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RateLimiter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
