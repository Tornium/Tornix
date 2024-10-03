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

defmodule Tornex.PromExPlugin do
  @moduledoc """
  PromEx plugin for Tornex to export events and metrics to Prometheus
  """

  use PromEx.Plugin

  @doc false
  @impl true
  def event_metrics(_opts) do
    [
      Event.build(
        :tornex_api_events,
        [
          counter(
            "tornex.api.finish",
            event_name: [:tornex, :api, :finish]
          ),
          distribution(
            "tornex.api.latency",
            event_name: [:tornex, :api, :finish],
            measurement: :latency,
            description: "The time it takes for the Torn API to respond to API calls.",
            reporter_options: [
              buckets: [0, 100, 250, 500, 1_000, 2_500, 5_000, 10_000]
            ],
            unit: {:native, :microsecond}
          ),
          counter(
            "tornex.api.errors",
            event_name: [:tornex, :api, :error],
            tags: [:error],
            description: "Errors returned by the Torn API"
          )
        ]
      ),
      Event.build(
        :tornex_bucket_events,
        [
          counter(
            "tornex.bucket.dump",
            event_name: [:tornex, :bucket, :dump]
          ),
          counter(
            "tornex.bucket.create",
            event_name: [:tornex, :bucket, :create]
          ),
          counter(
            "tornex.bucket.create.error",
            event_name: [:tornex, :bucket, :create_error]
          )
        ]
      )
    ]
  end
end
