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
  end

  describe "enqueue" do
    test "should cast the request with no reply" do
      {:ok, _pid} = RateLimiter.start_link()
      assert :ok = RateLimiter.enqueue({"message", "queue"})
    end
  end

  describe "init/1" do
    @describetag :init

    test "inits with an empty map of queue as state" do
      assert {:ok, %{}} = RateLimiter.init(:ok)
    end
  end

  describe "handle_cast({:in, message, queue}, state)" do
    @describetag :enqueue

    test "should create a new queue and put message in" do
      state = %{}
      message = 1
      queue = "queue"
      request = {:in, message, queue}
      assert {:noreply, state} = RateLimiter.handle_cast(request, state)
      assert state[queue], "should have new queue with that name"
      assert {[^message], []} = state[queue], "should have the message in the queue"
    end

    test "should put the message into existing queue" do
      state = %{}
      queue = "queue"
      request = {:in, 1, queue}
      {:noreply, state} = RateLimiter.handle_cast(request, state)
      request = {:in, 2, queue}
      assert {:noreply, state} = RateLimiter.handle_cast(request, state)
      assert state[queue], "should have the existing queue with that name"
      assert {[2], [1]} = state[queue], "should have the message in the queue"
    end
  end
end
