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

require "helper"

describe Google::Cloud::Spanner::Commit, :queues, :mock_spanner do
  it "builds an enqueue mutation correctly" do
    commit = Google::Cloud::Spanner::Commit.new
    now = Time.now

    commit.enqueue "TestQueue", [2], "Hello, Queues!", deliver_time: now

    assert_equal 1, commit.mutations.count
    mutation = commit.mutations.first

    assert mutation["send"]
    assert_equal "TestQueue", mutation["send"].queue
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value([2]).list_value, mutation["send"].key
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value("Hello, Queues!"), mutation["send"].payload
    assert_equal Google::Cloud::Spanner::Convert.time_to_timestamp(now), mutation["send"].deliver_time
  end

  it "builds an ack mutation correctly" do
    commit = Google::Cloud::Spanner::Commit.new

    commit.ack "TestQueue", [2], ignore_not_found: true

    assert_equal 1, commit.mutations.count
    mutation = commit.mutations.first

    assert mutation.ack
    assert_equal "TestQueue", mutation.ack.queue
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value([2]).list_value, mutation.ack.key
    assert_equal true, mutation.ack.ignore_not_found
  end
end
