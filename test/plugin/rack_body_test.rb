require "test_helper"
require "shrine/plugins/rack_body"
require "stringio"
require "rack"

describe Shrine::Plugins::RackBody do
  before do
    @uploader = uploader { plugin :rack_body }
    @shrine = @uploader.class
  end

  it "can create an IO-like object from Rack input" do
    request = Rack::Request.new("rack.input" => StringIO.new("content"))

    io = @shrine.rack_body(request)

    assert_equal 7, io.size
    refute io.eof?
    assert_equal "content", io.read
    assert io.eof?
    assert_equal "", io.read
    io.rewind
    assert_equal "cont", io.read(4)
    assert_equal "ent",  io.read(4)
    assert_nil           io.read(4)
    assert io.eof?
    io.close
    assert_raises(IOError) { io.read }
  end

  it "determines size from Content-Length" do
    request = Rack::Request.new("rack.input"     => IO.pipe[0],
                                "CONTENT_LENGTH" => "7")

    io = @shrine.rack_body(request)

    assert_equal 7, io.size
  end

  it "determines size from Rack input size" do
    request = Rack::Request.new("rack.input" => StringIO.new("content"))

    io = @shrine.rack_body(request)

    assert_equal 7, io.size
  end

  it "determines size if Content-Length is blank and Rack input doesn't have a size" do
    rack_input = StringIO.new("content")
    rack_input.instance_eval { undef size }

    request = Rack::Request.new("rack.input" => rack_input)

    io = @shrine.rack_body(request)

    assert_equal 7,         io.size
    assert_equal "content", io.read
  end

  it "extracts Content-Type" do
    request = Rack::Request.new("rack.input"   => StringIO.new("content"),
                                "CONTENT_TYPE" => "text/plain")

    io = @shrine.rack_body(request)

    assert_equal "text/plain", io.content_type
  end

  it "returns nil on blank Content-Type" do
    request = Rack::Request.new("rack.input"   => StringIO.new("content"),
                                "CONTENT_TYPE" => "")

    io = @shrine.rack_body(request)

    assert_nil io.content_type
  end

  it "raises EOFError when Rack input is smaller than Content-Length" do
    rack_input = StringIO.new("content")

    request = Rack::Request.new("rack.input"     => StringIO.new("content"),
                                "CONTENT_LENGTH" => "10")

    io = @shrine.rack_body(request)

    assert_raises(EOFError) { io.read }
  end
end
