# Copyright 2024 tiksan
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Tornex.Scheduler.Bucket do
  @moduledoc """
  `Tornex.Scheduler.Bucket` represents a user's bucket for API requests used for rate-limiting and prioritizing.
  
  A bucket can hold as many API requests as the computer can support. However, each bucket will only process 10 
  API requests every 6 seconds.

  The bucket provides the `enqueue/1` and `enqueue/2` operation that provides the core of the functionality of this module by creating
  the bucket if necessary, handling telemetry, and request handling.

  ## Bucket Creation
  Creating buckets is not required, but you can create and store buckets in a different manner if you need to do so.

  A buckets can be created with the following two methods:
    - `new/1` to create a bucket and store the PID of the GenServer manually
    - `enqueue/1` to create a bucket and let Tornex store the PID of the GenServer in a pre-initialized registry `Tornex.Scheduler.BucketRegistry`

  ## Making API Requests
  API requests are made with the `enqueue/1` and the `enqueue/2` operations with a `Tornex.Query` struct. The operations will then wait until the API call has been scheduled and the Torn API has responded instead of ending the invocation early and using a later `await`-like function.

  However, for example, this can still be done with the built-in `Task` module (including to handle many API requests at once): 

      1..10
      |> Enum.map(fn n ->
        Task.async(fn ->
          Tornex.Scheduler.Bucket.enqueue(pid, query)
        end)
      end)
      |> Task.await_many(timeout)
  """

  require Logger

  use GenServer

  @bucket_capacity 10

  # Public API
  def start_link(user_id) do
    GenServer.start_link(__MODULE__, :ok, name: {:via, Registry, {Tornex.Scheduler.BucketRegistry, user_id}})
  end

  @spec new(user_id :: integer()) :: pid() | nil
  def new(user_id) when is_integer(user_id) do
    bucket =
      DynamicSupervisor.start_child(
        Tornex.Scheduler.Supervisor,
        {Tornex.Scheduler.Bucket, user_id: user_id}
      )

    case bucket do
      {:ok, pid} ->
        :telemetry.execute([:tornex, :bucket, :create], %{}, %{user: user_id, pid: pid})
        pid

      {:ok, pid, _info} ->
        :telemetry.execute([:tornex, :bucket, :create], %{}, %{user: user_id, pid: pid})
        pid

      {:error, {:already_started, pid}} ->
        :telemetry.execute([:tornex, :bucket, :create_error], %{}, %{user: user_id, error: "Bucket already started"})
        pid

      {:error, error} ->
        :telemetry.execute([:tornex, :bucket, :create_error], %{}, %{user: user_id, error: error})
        nil

      _ ->
        nil
    end
  end

  @spec enqueue(query :: Tornex.Query.t()) :: any()
  def enqueue(%Tornex.Query{key_owner: key_owner} = query) when is_integer(key_owner) do
    :telemetry.execute([:tornex, :bucket, :enqueue], %{}, %{
      selections: query.selections,
      resource: query.resource,
      resource_id: query.resource_id,
      user: query.key_owner
    })

    case get_bucket_by_id(query.key_owner) do
      {:ok, pid} ->
        GenServer.call(pid, {:enqueue, query}, 60_000)

      :error ->
        pid = new(query.key_owner)

        # Adds GenServer to Registry in `start_link`
        GenServer.call(pid, {:enqueue, query}, 60_000)
    end
  end

  @spec enqueue(pid :: pid(), query :: Tornex.Query.t()) :: any()
  def enqueue(pid, %Tornex.Query{} = query) when is_pid(pid) do
    GenServer.call(pid, {:enqueue, query}, 60_000)
  end

  @spec get_bucket_by_id(user_id :: integer()) :: {:ok, pid()} | :error
  def get_bucket_by_id(user_id) when is_integer(user_id) do
    case Registry.lookup(Tornex.Scheduler.BucketRegistry, user_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  # GenServer Callbacks
  @impl true
  def init(_opts) do
    {:ok, %{query_priority_queue: [], pending_count: 0}}
  end

  @impl true
  def handle_call(
        {:enqueue, query},
        from,
        %{query_priority_queue: query_priority_queue, pending_count: pending_count} = state
      ) do
    # Add from to query in case the request is dumped for the reply to be sent
    query = %{query | origin: from}

    cond do
      Tornex.Query.query_priority(query) == :user_request and pending_count < @bucket_capacity ->
        # Request has a niceness indicating it's a user request and there's available space in the 
        # bucket to perform the request

        make_request(query, from)
        state = Map.replace(state, :pending_count, pending_count + 1)
        {:noreply, state}

      Tornex.Query.query_priority(query) in [:user_request, :high_priority] and pending_count < 0.7 * @bucket_capacity ->
        # Request has a niceness indicating it's a user request or high priority and there's available 
        # space in the bucket to perform the request

        make_request(query, from)
        state = Map.replace(state, :pending_count, pending_count + 1)
        {:noreply, state}

      true ->
        # Either:
        #  - Request has a niceness indicating it's a user request or high priority request but there's not 
        #    available space in the bucket to perform the request and thus is queued
        #  - Request has a niceness of greater than 0 and therefore isn't high enough priority and should
        #    be queued

        # Sorts inserted query with higher priority queries at the start
        updated_queue = Enum.sort_by([query | query_priority_queue], & &1.nice, :asc)
        state = Map.replace(state, :query_priority_queue, updated_queue)

        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:dump, state) do
    {dumped_queries, remaining_queries} = Enum.split(state.query_priority_queue, @bucket_capacity - state.pending_count)

    Map.replace(state, :pending_count, 0)
    Map.replace(state, :query_priority_queue, remaining_queries)
    Enum.map(dumped_queries, fn query -> make_request(query, query.origin) end)

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Utility functions
  defp make_request_task(query, from) do
    GenServer.reply(from, Tornex.API.torn_get(query))
  end

  def make_request(query, from) do
    Task.Supervisor.async_nolink(Tornex.Scheduler.TaskSupervisor, fn ->
      make_request_task(query, from)
    end)
  end
end
