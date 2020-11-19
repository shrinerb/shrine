require "test_helper"
require "shrine/plugins/bounded_rack_request"
require "stringio"
require "rack"

describe Shrine::Plugins::BoundedRackRequest do
  InputTooLarge = Shrine::Plugins::BoundedRackRequest::InputTooLarge

  before do
    @uploader = uploader { plugin :bounded_rack_request }
    @shrine = @uploader.class
  end

  it "raises InputTooLarge when Content-Length is too large" do
    request = Rack::Request.new("rack.input"     => IO.pipe[0],
                                "CONTENT_LENGTH" => "10")

    assert_raises(InputTooLarge) { @shrine.bounded_rack_request(request, 5) }
  end

  it "raises InputTooLarge when Rack input size is too large" do
    request = Rack::Request.new("rack.input" => StringIO.new("content"))

    assert_raises(InputTooLarge) { @shrine.bounded_rack_request(request, 5) }
  end

  it "returns a Rack::Request with bounded rack.input" do
    rack_input = StringIO.new("line1\nline2")
    rack_input.instance_eval { undef size }

    request = Rack::Request.new("rack.input" => rack_input)
    bounded_request = @shrine.bounded_rack_request(request, 6)

    assert_instance_of Rack::Request, bounded_request

    body = bounded_request.body
    assert_raises(InputTooLarge) { body.read }
    body.rewind
    assert_equal "line1\n", body.read(6)
    assert_raises(InputTooLarge) { body.read(1) }
    body.rewind
    assert_equal "line1\n", body.gets
    body.rewind
    lines = body.enum_for(:each)
    assert_equal "line1\n", lines.next
    assert_raises(InputTooLarge) { lines.next }
    body.close
    assert_raises(IOError) { body.read }
  end
end
