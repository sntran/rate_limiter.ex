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

    test "takes a keyword list for options" do
      assert {:ok, pid} = RateLimiter.start_link([])
    end

    test "can take an option for the time in milliseconds between job" do
      assert {:ok, pid} = RateLimiter.start_link([time: 2000])
    end
  end

  describe "enqueue" do
    test "should cast the request with no reply" do
      {:ok, _pid} = RateLimiter.start_link()
      assert :ok = RateLimiter.enqueue({"message", "queue"})
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
      message = fn() ->
        Kernel.send(:tester, {:process, queue})
      end

      {:noreply, state} = RateLimiter.handle_cast({:in, message, queue}, state)
      {:noreply, _state} = RateLimiter.handle_info({:process, queue}, state)

      assert_received {:process, ^queue}, "message should be executed"
    end
  end
end
