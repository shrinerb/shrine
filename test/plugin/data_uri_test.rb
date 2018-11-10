require "test_helper"
require "shrine/plugins/data_uri"
require "base64"

describe Shrine::Plugins::DataUri do
  before do
    @attacher = attacher { plugin :data_uri }
    @user = @attacher.record
    @shrine = @attacher.shrine_class
  end

  it "enables caching with a data URI" do
    @user.avatar_data_uri = "data:image/png,content"
    assert @user.avatar
    assert_equal "content", @user.avatar.read
    assert_equal "image/png", @user.avatar.mime_type
  end

  it "ignores empty strings" do
    @user.avatar = fakeio
    @user.avatar_data_uri = ""
    assert @user.avatar
    assert_nil @user.avatar_data_uri
  end

  it "ignores nil values" do
    @user.avatar = fakeio
    @user.avatar_data_uri = nil
    assert @user.avatar
    assert_nil @user.avatar_data_uri
  end

  it "retains the data uri value if uploading doesn't succeed" do
    @user.avatar_data_uri = "data:image/png,content"
    assert_nil @user.avatar_data_uri
    @user.avatar_data_uri = "foo"
    assert_equal "foo", @user.avatar_data_uri
  end

  it "adds a validation error if data_uri wasn't properly matched" do
    @user.avatar_data_uri = "bla"
    assert_equal ["data URI has invalid format"], @user.avatar_attacher.errors
  end

  it "clears any existing errors" do
    @user.avatar_attacher.errors << "foo"
    @user.avatar_data_uri = "bla"
    assert_equal ["data URI has invalid format"], @user.avatar_attacher.errors
  end

  it "can create an IO object from the data URI" do
    io = @shrine.data_uri("data:image/png,content")
    assert_instance_of StringIO, io.to_io
    assert_equal "image/png", io.content_type
    assert_equal "content", io.read
    assert_equal 7, io.size
    assert_equal true, io.eof?
    io.rewind
    assert_equal false, io.eof?
    io.close
  end

  it "extracts valid content type" do
    io = @shrine.data_uri("data:image/png,content")
    assert_equal "image/png", io.content_type

    io = @shrine.data_uri("data:application/vnd.api+json,content")
    assert_equal "application/vnd.api+json", io.content_type

    io = @shrine.data_uri("data:application/vnd.api+json;charset=utf-8,content")
    assert_equal "application/vnd.api+json;charset=utf-8", io.content_type

    assert_raises(Shrine::Plugins::DataUri::ParseError) do
      @shrine.data_uri("data:application/vnd.api&json,content")
    end

    io = @shrine.data_uri("data:,content")
    assert_equal "text/plain", io.content_type

    assert_raises(Shrine::Plugins::DataUri::ParseError) do
      @shrine.data_uri("data:content")
    end
  end

  it "URI-decodes raw content" do
    io = @shrine.data_uri("data:,raw%20content")
    assert_equal "raw content", io.read

    io = @shrine.data_uri("data:,raw content")
    assert_equal "raw content", io.read
  end

  it "handles base64 data URIs" do
    io = @shrine.data_uri("data:image/png;base64,#{Base64.encode64("content")}")
    assert_equal "image/png", io.content_type
    assert_equal "content",   io.read

    io = @shrine.data_uri("data:image/png;param=value;base64,#{Base64.encode64("content")}")
    assert_equal "image/png;param=value", io.content_type
    assert_equal "content",               io.read

    io = @shrine.data_uri("data:;base64,#{Base64.encode64("content")}")
    assert_equal "text/plain", io.content_type
    assert_equal "content",    io.read

    assert_raises(Shrine::Plugins::DataUri::ParseError) do
      @shrine.data_uri("data:base64,#{Base64.encode64("content")}")
    end
  end

  it "accepts data URIs with blank content" do
    io = @shrine.data_uri("data:,")
    assert_equal "", io.read
    assert_equal 0,  io.size
  end

  it "accepts :filename" do
    io = @shrine.data_uri("data:,content", filename: "foo.txt")
    assert_equal "foo.txt", io.original_filename
  end

  deprecated "can generate filenames" do
    @shrine.plugin :data_uri, filename: ->(c) { "data_uri.#{c.split("/").last}" }
    io = @shrine.data_uri("data:image/png,content")
    assert_equal "image/png",    io.content_type
    assert_equal "data_uri.png", io.original_filename
  end

  it "adds #data_uri and #base64 methods to UploadedFile" do
    @user.avatar = fakeio(Base64.decode64("a" * 120))
    assert_equal "data:text/plain;base64,#{"a" * 120}", @user.avatar.data_uri
    assert_equal "a" * 120, @user.avatar.base64
  end
end
