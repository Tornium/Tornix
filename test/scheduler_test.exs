defmodule Tornex.Test.Scheduler do
  @test_api_key "asdf1234asdf1234"

  use ExUnit.Case

  test "test_start_supervisor" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    DynamicSupervisor.stop(s_pid)
  end

  test "test_genserver_single" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    {:ok, pid} = DynamicSupervisor.start_child(s_pid, Tornex.Scheduler.Bucket)

    %{"error" => %{"code" => 2}} =
      Tornex.Scheduler.Bucket.enqueue(pid, %Tornex.Query{
        resource: "user",
        resource_id: 1,
        key: @test_api_key,
        key_owner: 2_383_326,
        nice: 0
      })

    GenServer.stop(pid)
    Supervisor.stop(s_pid)
  end

  test "test_genserver_multiple" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    {:ok, pid} = DynamicSupervisor.start_child(s_pid, Tornex.Scheduler.Bucket)

    1..10
    |> Enum.map(fn n ->
      Task.async(fn ->
        Tornex.Scheduler.Bucket.enqueue(pid, %Tornex.Query{
          resource: "user",
          resource_id: n,
          key: @test_api_key,
          key_owner: 2_383_326,
          nice: -5
        })
      end)
    end)
    |> Task.await_many(60000)

    GenServer.stop(pid)
    Supervisor.stop(s_pid)
  end

  test "test_genserver_multiple_low_priority" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    {:ok, pid} = DynamicSupervisor.start_child(s_pid, Tornex.Scheduler.Bucket)

    1..10
    |> Enum.map(fn n ->
      Task.async(fn ->
        Tornex.Scheduler.Bucket.enqueue(pid, %Tornex.Query{
          resource: "user",
          resource_id: n,
          key: @test_api_key,
          key_owner: 2_383_326,
          nice: 0 + n
        })
      end)
    end)
    |> Task.await_many(60000)

    GenServer.stop(pid)
    Supervisor.stop(s_pid)
  end

  test "test_genserver_new_bucket" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    {:ok, pid} = DynamicSupervisor.start_child(s_pid, Tornex.Scheduler.Bucket)

    %{"error" => %{"code" => 2}} =
      Tornex.Scheduler.Bucket.enqueue(%Tornex.Query{
        resource: "user",
        resource_id: 1,
        key: @test_api_key,
        key_owner: 2_383_326,
        nice: 0
      })

    GenServer.stop(pid)
    Supervisor.stop(s_pid)
  end
end
