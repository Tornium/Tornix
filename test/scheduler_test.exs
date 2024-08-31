defmodule Tornex.Test.Scheduler do
  @test_api_key "asdf1234asdf1234"

  use ExUnit.Case

  test "test_start_supervisor" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    DynamicSupervisor.stop(s_pid)
  end

  test "test_genserver_basic" do
    {:ok, pid} = Tornex.Scheduler.Bucket.start_link([])
    GenServer.stop(pid)
  end

  test "test_genserver_single" do
    {:ok, s_pid} = ExUnit.Callbacks.start_supervised(Tornex.Scheduler.Supervisor)
    {:ok, pid} = Tornex.Scheduler.Bucket.start_link([])

    {:error, {:api, 2}} = Tornex.Scheduler.Bucket.enqueue(pid, %Tornex.Query{
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
    {:ok, pid} = Tornex.Scheduler.Bucket.start_link([])

    1..10
    |> Enum.map(fn n -> Task.async(fn -> Tornex.Scheduler.Bucket.enqueue(pid, %Tornex.Query{
      resource: "user",
      resource_id: n,
      key: @test_api_key,
      key_owner: 2_383_326,
      nice: -5 + n
    }) end) end)
    |> Task.await_many(60000)

    GenServer.stop(pid)
    Supervisor.stop(s_pid)
  end
end
