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
  it "builds an enqueue mutation with scalar key" do
    commit = Google::Cloud::Spanner::Commit.new
    now = Time.now

    commit.enqueue "TestQueue", 2, "Hello, Queues!", deliver_time: now

    assert_equal 1, commit.mutations.count
    mutation = commit.mutations.first

    assert mutation["send"]
    assert_equal "TestQueue", mutation["send"].queue
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value([2]).list_value, mutation["send"].key
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value("Hello, Queues!"), mutation["send"].payload
    assert_equal Google::Cloud::Spanner::Convert.time_to_timestamp(now), mutation["send"].deliver_time
  end

  it "builds an enqueue mutation with composite key" do
    commit = Google::Cloud::Spanner::Commit.new

    commit.enqueue "TestQueue", ["tenant1", 2], "Hello, Queues!"

    assert_equal 1, commit.mutations.count
    mutation = commit.mutations.first

    assert mutation["send"]
    assert_equal "TestQueue", mutation["send"].queue
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value(["tenant1", 2]).list_value, mutation["send"].key
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value("Hello, Queues!"), mutation["send"].payload
    assert_nil mutation["send"].deliver_time
  end

  it "encodes binary IO and ASCII-8BIT string payloads as Base64" do
    commit = Google::Cloud::Spanner::Commit.new

    raw_bytes = "\x00\x01\x02\xFF".b
    io_bytes = StringIO.new raw_bytes

    commit.enqueue "TestQueue", 1, io_bytes
    commit.enqueue "TestQueue", 2, raw_bytes

    assert_equal 2, commit.mutations.count
    m1 = commit.mutations[0]
    m2 = commit.mutations[1]

    expected_b64 = Base64.strict_encode64 raw_bytes
    assert_equal expected_b64, m1["send"].payload.string_value
    assert_equal expected_b64, m2["send"].payload.string_value
  end

  it "encodes Hash payload as JSON string" do
    commit = Google::Cloud::Spanner::Commit.new
    hash_payload = { "event" => "user_created", "status" => "active" }

    commit.enqueue "TestQueue", 1, hash_payload

    assert_equal 1, commit.mutations.count
    mutation = commit.mutations.first

    assert_equal hash_payload.to_json, mutation["send"].payload.string_value
  end

  it "raises ArgumentError for unsupported payload types" do
    commit = Google::Cloud::Spanner::Commit.new

    assert_raises ArgumentError do
      commit.enqueue "TestQueue", 1, Object.new
    end
  end

  it "builds an ack mutation with scalar and composite keys" do
    commit = Google::Cloud::Spanner::Commit.new

    commit.ack "TestQueue", 2, ignore_not_found: true
    commit.ack "TestQueue", ["tenant1", 2]

    assert_equal 2, commit.mutations.count
    m1 = commit.mutations[0]
    m2 = commit.mutations[1]

    assert m1.ack
    assert_equal "TestQueue", m1.ack.queue
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value([2]).list_value, m1.ack.key
    assert_equal true, m1.ack.ignore_not_found

    assert m2.ack
    assert_equal "TestQueue", m2.ack.queue
    assert_equal Google::Cloud::Spanner::Convert.object_to_grpc_value(["tenant1", 2]).list_value, m2.ack.key
    assert_equal false, m2.ack.ignore_not_found
  end
end
