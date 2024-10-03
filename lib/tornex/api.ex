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

# TODO: Remove all unused methods and types originating in `Tesla` from `Tornex.API`

defmodule Tornex.API do
  use Tesla

  @user_agent [{"User-agent", "tornex" <> Mix.Project.config()[:version]}]

  plug(Tesla.Middleware.BaseUrl, "https://api.torn.com")
  plug(Tesla.Middleware.Headers, @user_agent)
  plug(Tesla.Middleware.JSON)

  @spec append_resource_id(String.t(), Tornex.Query.t()) :: String.t()
  defp append_resource_id(uri_string, %Tornex.Query{resource_id: nil} = _) do
    uri_string
  end

  defp append_resource_id(uri_string, query) when is_binary(query.resource_id) do
    uri_string <> query.resource_id
  end

  defp append_resource_id(uri_string, query) when is_integer(query.resource_id) do
    uri_string <> Integer.to_string(query.resource_id)
  end

  @spec query_to_url(Tornex.Query.t()) :: String.t()
  def query_to_url(%Tornex.Query{} = query) do
    ("/" <> query.resource <> "/")
    |> append_resource_id(query)
    |> Tesla.build_url(
      selections: Enum.join(query.selections || [], ","),
      from: query.from || [],
      to: query.to || [],
      timestamp: query.timestamp || [],
      key: query.key,
      comment: "Tornex"
    )
  end

  @spec torn_get(Tornex.Query.t()) :: {:ok, Map} | {:error, any()}
  def torn_get(%Tornex.Query{} = query) do
    :telemetry.execute([:tornex, :api, :start], %{}, %{
      resource: query.resource,
      resource_id: query.resource_id,
      selections: query.selections,
      user: query.key_owner
    })

    # {latency, response} = :timer.tc(Tesla, :get, [query_to_url(query)])
    {latency, response} = :timer.tc(&get/1, [query_to_url(query)])

    case response do
      {:ok, %Tesla.Env{} = response} ->
        :telemetry.execute([:tornex, :api, :finish], %{latency: latency}, %{
          resource: query.resource,
          resource_id: query.resource_id,
          selections: query.selections,
          user: query.key_owner,
          status: response.status
        })

        response.body

      {:error, e} ->
        :telemetry.execute([:tornex, :api, :finish], %{latency: latency}, %{
          resource: query.resource,
          resource_id: query.resource_id,
          selections: query.selections,
          user: query.key_owner
        })

        IO.inspect(e)

        {:error, :unknown}
    end
  end
end
