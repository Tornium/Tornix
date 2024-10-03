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

defmodule Tornex.Telemetry do
  @moduledoc """
  Telemetry for Tornex

  `Tornex.Telemetry` defaults to using `Logger` to handle telemetry events but this can be 
  customized by not attaching the default logger.
  """

  # TODO: Document the individual events

  require Logger

  @handler_id "tornex-default-telemetry-handler"

  @doc """
  Attach the default built-in log handler to Tornex Telemetry
  """
  @spec attach_default_logger(opts :: Keyword) :: :ok | {:error, :already_exists}
  def attach_default_logger(opts \\ []) when is_list(opts) do
    events = [
      [:tornex, :api, :start],
      [:tornex, :api, :finish],
      [:tornex, :api, :error],
      [:tornex, :bucket, :create],
      [:tornex, :bucket, :create_error],
      [:tornex, :bucket, :dump],
      [:tornex, :bucket, :enqueue]
    ]

    opts =
      opts
      |> Keyword.put_new(:encode, true)
      |> Keyword.put_new(:level, :info)

    :telemetry.attach_many(@handler_id, events, &__MODULE__.handle_event/4, opts)
  end

  @doc false
  @spec detach_default_logger() :: :ok | {:error, :not_found}
  def detach_default_logger() do
    :telemetry.detach(@handler_id)
  end

  @doc false
  def handle_event([:tornex, :api, :start], _measurements, metadata, _opts) do
    Logger.debug(
      "[#{metadata.resource}/#{metadata.resource_id || ""}?selections=#{Enum.join(metadata.selections || [], ",")}] Request started for #{metadata.user}"
    )
  end

  def handle_event([:tornex, :api, :finish], measurements, metadata, _opts) do
    Logger.debug(
      "[#{metadata.resource}/#{metadata.resource_id || ""}?selections=#{Enum.join(metadata.selections || [], ",")}] [HTTP #{metadata.status}] Request finished in #{measurements.latency} ms"
    )
  end

  def handle_event([:tornex, :api, :error], measurements, metadata, _opts) do
    Logger.info(
      "[#{metadata.resource}/#{metadata.resource_id || ""}?selections=#{Enum.join(metadata.selections || [], ",")}] Requested failed due to #{metadata.error} in #{measurements.latency} ms"
    )
  end

  def handle_event([:tornex, :bucket, :create], _measurements, metadata, _opts) do
    Logger.info("Bucket created for #{metadata.user}")
  end

  def handle_event([:tornex, :bucket, :create_error], _measurements, metadata, _opts) do
    Logger.warning("Bucket creation failed for #{metadata.user} due to #{metadata.error}")
  end

  def handle_event([:tornex, :bucket, :dump], _measurements, _metadata, _opts) do
    Logger.debug("Dump of buckets started")
  end

  def handle_event([:tornex, :bucket, :enqueue], _measurements, metadata, _opts) do
    Logger.debug(
      "[#{metadata.resource}/#{metadata.resource_id || ""}?selections=#{Enum.join(metadata.selections || [], ",")}] Request enqueue for #{metadata.user}"
    )
  end

  def handle_event([:tornex, _event_type, _event], _measurements, _metadata, _opts) do
    :ok
  end
end
