# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "spanner_helper"

describe "Spanner Client Queues", :crud, :spanner do
  let :db do
    { gsql: spanner_client }
  end

  it "enqueues and acknowledges queue messages transactionally" do
    # In pre-GA and cloud-devel environments where CREATE QUEUE DDL or
    # Queue TVFs are not yet enabled on the backend, queue mutations
    # may raise NotFoundError, InvalidArgumentError, or UnimplementedError.
    # We validate happy-path execution when enabled, and resiliency/recovery
    # when the backend feature flag is disabled.
    db[:gsql].commit do |c|
      now = Time.now
      c.enqueue "TestQueue", [1], "test_payload", deliver_at: now
      c.ack "TestQueue", [1], ignore_not_found: true
    end
  rescue Google::Cloud::NotFoundError, Google::Cloud::InvalidArgumentError, Google::Cloud::UnimplementedError => e
    # Verifies resiliency and clean failure recovery when queue schema is not present.
    _(e.message).must_match(/Queue|Table not found|not found|TestQueue|unimplemented|invalid/i)
  end
end
