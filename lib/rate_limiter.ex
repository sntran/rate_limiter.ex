defmodule RateLimiter do
  @moduledoc """
  A worker to output incoming messages at a rate.

  This Elixir application accepts messages via an HTTP endpoint and processes 
  the messages in the order that they are received, and no more than one per 
  second. The application should be able to handle multiple queues based on a 
  parameter passed into the HTTP endpoint.

  1. The application is a simple Plug based web server.
  2. The application has an HTTP endpoint at the path `/receive-message` which 
     accepts a GET request with the query string parameters: `queue` (string), 
    `message` (string).
  3. The application will accept messages as quickly as they come in and return 
     a 200 status code.
  4. The application will "process" the messages by printing the message text 
     to the terminal, however for each queue, the application should only 
     "process" one message a second, no matter how quickly the messages are 
     submitted to the HTTP endpoint.
  5. Tests that verifies messages are only processed one per second.

  ## Examples

      iex> {:ok, _pid} = RateLimiter.start_link()
      iex> RateLimiter.enqueue({"message", "queue"})
      :ok

  """

  use GenServer

  @doc """
  Starts a `RateLimiter` worker linked to the current process.

  The worker process is named so it can be sent messages without specifying its
  `pid` or module name.

  Once the worker is started, an empty map is created to store all the queues
  by their name.

  ## Examples

      iex> {:ok, pid} = RateLimiter.start_link()
      iex> Process.whereis(RateLimiter) === pid
      true

  """
  def start_link() do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Places a message into a queue.

  This is an asynchronous request and always returns `:ok`.

  The message will be placed in a queue with specified name, or new queue if it
  does not exist yet.
  """
  def enqueue({_message, _queue} = request) do
    GenServer.cast(__MODULE__, request)
  end

  # Callbacks

  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:in, message, queue_name}, state) do
    queue = Map.get(state, queue_name, :queue.new())
    queue = :queue.in(message, queue)
    state = Map.put(state, queue_name, queue)
    {:noreply, state}
  end
end
