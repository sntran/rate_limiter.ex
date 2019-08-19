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

  defstruct queues: %{}, options: []

  @type t :: %__MODULE__{}

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
  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(options \\ []) do
    case GenServer.start_link(__MODULE__, options, name: __MODULE__) do
      {:error, {:already_started, pid}} -> {:ok, pid}
      other -> other
    end
  end

  @doc """
  Places a message into a queue.

  This is an asynchronous request and always returns `:ok`.

  The message will be placed in a queue with specified name, or new queue if it
  does not exist yet.
  """
  @spec enqueue({String.t() | function(), String.t()}) :: :ok
  def enqueue({message, queue}) do
    GenServer.cast(__MODULE__, {:in, message, queue})
  end

  # Callbacks

  @impl GenServer
  def init(options) do
    {:ok, %__MODULE__{options: options, queues: %{}}}
  end

  @impl GenServer
  def handle_cast({:in, message, queue_name}, %{queues: queues} = state) do
    queue = Map.get(queues, queue_name)

    if (is_nil(queue)) do
      schedule_queue(queue_name)
    end

    queue = :queue.in(message, queue || :queue.new())
    queues = Map.put(queues, queue_name, queue)
    {:noreply, Map.put(state, :queues, queues)}
  end

  @impl GenServer
  def handle_info({:process, queue_name}, %{queues: queues} = state) do
    # @TODO: Use the time specified in options.
    schedule_queue(queue_name, 1 * 1000)

    queue = queues
    |> Map.get(queue_name)
    |> :queue.out()
    |> case do
      {{:value, message}, queue} ->
        process(message, queue_name)
        queue
      {:empty, queue} ->
        queue
    end

    queues = Map.put(queues, queue_name, queue)
    {:noreply, Map.put(state, :queues, queues)}
  end

  defp schedule_queue(queue_name, time \\ 0) do
    time = System.monotonic_time(:millisecond) + time
    Process.send_after(self(), {:process, queue_name}, time, abs: true)
  end

  defp process(message, queue_name) when is_function(message) do
    message.(queue_name)
  end

  defp process(_message, _queue_name) do
    :ok
  end
end
