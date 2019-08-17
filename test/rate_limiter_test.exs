defmodule RateLimiterTest do
  use ExUnit.Case
  doctest RateLimiter

  describe "start_link" do
    @describetag :start_link

    test "is a process" do
      assert {:ok, pid} = RateLimiter.start_link()
      assert is_pid(pid)
    end

    test "is named" do
      {:ok, pid} = RateLimiter.start_link()
      assert Process.whereis(RateLimiter) === pid
    end

    test "is a singleton" do
      {:ok, pid} = RateLimiter.start_link()
      assert {:ok, ^pid} = RateLimiter.start_link()
    end

    test "takes a keyword list for options" do
      assert {:ok, pid} = RateLimiter.start_link([])
    end

    test "can take an option for the time in milliseconds between job" do
      assert {:ok, pid} = RateLimiter.start_link([time: 2000])
    end
  end

  describe "init/1" do
    @describetag :init

    test "takes an options and inits with a state" do
      assert {:ok, state} = RateLimiter.init([])
      assert state.queues === %{}, "should have empty map of queues"
      assert state.options === [], "should keep the options internally"

      options = [time: 2000]
      assert {:ok, state} = RateLimiter.init(options)
      assert state.queues === %{}, "should have empty map of queues"
      assert state.options === options, "should keep the passed options internally"
    end
  end

  describe "handle_cast({:in, message, queue}, state)" do
    @describetag :enqueue

    test "should create a new queue and put message in" do
      {:ok, state} = RateLimiter.init([])
      message = 1
      queue = "queue"
      request = {:in, message, queue}
      assert {:noreply, state} = RateLimiter.handle_cast(request, state)
      assert state.queues[queue], "should have new queue with that name"
      assert {[^message], []} = state.queues[queue], "should have the message in the queue"
    end

    test "should put the message into existing queue" do
      {:ok, state} = RateLimiter.init([])
      queue = "queue"
      request = {:in, 1, queue}
      {:noreply, state} = RateLimiter.handle_cast(request, state)
      request = {:in, 2, queue}
      assert {:noreply, state} = RateLimiter.handle_cast(request, state)
      assert state.queues[queue], "should have the existing queue with that name"
      assert {[2], [1]} = state.queues[queue], "should have the message in the queue"
    end
  end

  describe "handle_info({:process, queue}, state)" do
    setup do
      Process.register(self(), :tester)

      on_exit(fn -> 
        :ok
      end)

      :ok
    end

    test "should removes the item at the front of the queue" do
      {:ok, state} = RateLimiter.init([])
      queue = "queue"
      {:noreply, state} = RateLimiter.handle_cast({:in, 1, queue}, state)
      {:noreply, state} = RateLimiter.handle_cast({:in, 2, queue}, state)

      assert {:noreply, state} = RateLimiter.handle_info({:process, queue}, state)
      assert {[], [2]} = state.queues[queue], "should not have the first message in the queue"

      assert {:noreply, state} = RateLimiter.handle_info({:process, queue}, state)
      assert {[], []} = state.queues[queue], "should not have the second message in the queue"
    end

    test "should execute the message if it is a function" do
      {:ok, state} = RateLimiter.init([])
      queue = "queue"
      message = fn(_queue_name) ->
        Kernel.send(:tester, {:process, queue})
      end

      {:noreply, state} = RateLimiter.handle_cast({:in, message, queue}, state)
      {:noreply, _state} = RateLimiter.handle_info({:process, queue}, state)

      assert_received {:process, ^queue}, "message should be executed"
    end
  end

  describe "enqueue" do
    setup do
      Process.register(self(), :tester)
      {:ok, pid} = RateLimiter.start_link()

      on_exit(fn -> 
        :ok
      end)

      [pid: pid]
    end

    test "should cast the request with no reply" do
      assert :ok = RateLimiter.enqueue({"message", "queue"})
    end

    test "should process the initial message immediately", context do
      pid = context[:pid]
      :erlang.trace(pid, true, [:receive, :monotonic_timestamp])

      queue_name = "queue"

      now = :erlang.monotonic_time()
      assert :ok = RateLimiter.enqueue({"message", queue_name})
      assert_receive(
        {:trace_ts, ^pid, :receive, {:process, ^queue_name}, timestamp}, 
        100, 
        "message should be processed"
      )

      duration = :erlang.convert_time_unit(timestamp - now, :native, :millisecond)
      assert (duration >= 0 and duration <= 1), "message should be processed immediately, not after #{duration}ms"
    end

    test "should schedule next messages in 1s interval", context do
      pid = context[:pid]
      :erlang.trace(pid, true, [:receive, :monotonic_timestamp])

      queue_name = "queue"

      # Enqueue consecutives messages.
      assert :ok = RateLimiter.enqueue({1, queue_name})
      assert :ok = RateLimiter.enqueue({2, queue_name})
      assert :ok = RateLimiter.enqueue({3, queue_name})

      assert_receive(
        {:trace_ts, ^pid, :receive, {:process, ^queue_name}, timestamp1}, 
        100, 
        "message 1 should be processed"
      )
      assert_receive(
        {:trace_ts, ^pid, :receive, {:process, ^queue_name}, timestamp2}, 
        1100,
        "message 2 should be processed"
      )

      duration = :erlang.convert_time_unit(timestamp2 - timestamp1, :native, :millisecond)
      assert (duration >= 1000 and duration < 1005), "message 2 should be processed after 1000ms, not #{duration}ms"
    
      assert_receive(
        {:trace_ts, ^pid, :receive, {:process, ^queue_name}, timestamp3}, 
        1100,
        "message 2 should be processed"
      )

      duration = :erlang.convert_time_unit(timestamp3 - timestamp2, :native, :millisecond)
      assert (duration >= 1000 and duration < 1005), "message 3 should be processed after 1000ms, not #{duration}ms"

    end
  end
end
