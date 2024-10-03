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

defmodule Tornex.Query do
  @moduledoc """
  Struct container for Torn API queries.

  `Query` is used to provide query data to the URL builder within `Tornex.API.torn_get/1`.

  ## Nice
  The `nice` key/value in `Query` follows how the nice value in the Linux scheduler works. 
  -20 is the highest priority request while 20 is the lowest priority request. Additionally,
  [-20, -10] is considered to be a user-originating request and is the highest priority, (-10, 0] 
  is considered to be a high priority request but an automated request, (0, 20] is considered 
  to be a low priority, automated request (as seen in `query_priority/1`).
  """

  # TODO: Define required keys

  @type t :: %__MODULE__{
          resource: String.t(),
          resource_id: Integer | String.t(),
          key: String.t(),
          selections: List,
          from: Integer,
          to: Integer,
          timestamp: Integer,
          limit: Integer,
          sort: :asc | :desc,

          # Values required for the scheduler
          key_owner: Integer,
          nice: Integer,
          origin: GenServer.from() | nil
        }
  defstruct [
    :resource,
    :resource_id,
    :key,
    :selections,
    :from,
    :to,
    :timestamp,
    :limit,
    :sort,

    # Values required for the scheduler
    :key_owner,
    :nice,
    :origin
  ]

  @doc """
  Determine the priority of a query as a priority "bucket" atom.
  """
  @spec query_priority(Tornex.Query.t()) :: :user_request | :high_priority | :generic_request
  def query_priority(%Tornex.Query{} = query) do
    cond do
      query.nice <= -10 -> :user_request
      query.nice <= 0 -> :high_priority
      true -> :generic_request
    end
  end
end
