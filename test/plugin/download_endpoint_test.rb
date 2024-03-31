require "test_helper"
require "shrine/plugins/download_endpoint"
require "uri"

describe Shrine::Plugins::DownloadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(endpoint), { Rack::SERVER_PROTOCOL => "HTTP/1.1" })
  end

  def endpoint
    @shrine.download_endpoint
  end

  before do
    @uploader = uploader { plugin :download_endpoint }
    @shrine = @uploader.class
    @uploaded_file = @uploader.upload(fakeio)
  end

  it "returns a file response" do
    io = fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024, content_type: "text/plain", filename: "content.txt")
    @uploaded_file = @uploader.upload(io)
    response = app.get(@uploaded_file.download_url)
    assert_equal 200, response.status
    assert_equal @uploaded_file.read, response.body_binary
    assert_equal @uploaded_file.size.to_s, response.headers[CONTENT_LENGTH_HEADER]
    assert_equal @uploaded_file.mime_type, response.headers[CONTENT_TYPE_HEADER]
    assert_equal ContentDisposition.inline(@uploaded_file.original_filename), response.headers[CONTENT_DISPOSITION_HEADER]
  end

  it "applies :download_options hash" do
    @shrine.plugin :download_endpoint, download_options: { foo: "bar" }
    @uploaded_file.storage.expects(:open).with(@uploaded_file.id, foo: "bar").returns(StringIO.new("options"))
    response = app.get(@uploaded_file.download_url)
    assert_equal "options", response.body_binary
  end

  it "applies :download_options proc" do
    @shrine.plugin :download_endpoint, download_options: -> (uploaded_file, request) { { foo: "bar" } }
    @uploaded_file.storage.expects(:open).with(@uploaded_file.id, foo: "bar").returns(StringIO.new("options"))
    response = app.get(@uploaded_file.download_url)
    assert_equal "options", response.body_binary
  end

  it "applies :disposition to response" do
    @shrine.plugin :download_endpoint, disposition: "attachment"
    response = app.get(@uploaded_file.download_url)
    assert_equal ContentDisposition.attachment(@uploaded_file.id), response.headers[CONTENT_DISPOSITION_HEADER]
  end

  it "returns Cache-Control" do
    response = app.get(@uploaded_file.download_url)
    assert_equal "max-age=31536000", response.headers[CACHE_CONTROL_HEADER]
  end

  it "accepts :redirect with true" do
    @shrine.plugin :download_endpoint, redirect: true
    response = app.get(@uploaded_file.download_url)
    assert_equal 302, response.status
    assert_match %r{^memory://\w+$}, response.headers[LOCATION_HEADER]
  end

  it "accepts :redirect with proc" do
    @shrine.plugin :download_endpoint, redirect: -> (uploaded_file, request) { "/foo" }
    response = app.get(@uploaded_file.download_url)
    assert_equal 302, response.status
    assert_equal "/foo", response.headers[LOCATION_HEADER]
  end

  it "returns Accept-Ranges" do
    response = app.get(@uploaded_file.download_url)
    assert_equal "bytes", response.headers[ACCEPT_RANGES_HEADER]
  end

  it "supports ranged requests" do
    @uploaded_file = @uploader.upload(fakeio("content"))
    response = app.get(@uploaded_file.download_url, headers: { "Range" => "bytes=2-4" })
    assert_equal 206,           response.status
    assert_equal "bytes 2-4/7", response.headers[CONTENT_RANGE_HEADER]
    assert_equal "3",           response.headers[CONTENT_LENGTH_HEADER]
    assert_equal "nte",         response.body_binary
  end

  it "returns ETag" do
    response = app.get(@uploaded_file.download_url)
    assert_instance_of String,    response.headers[ETAG_HEADER]
    assert_match /^W\/"\w{32}"$/, response.headers[ETAG_HEADER]
  end

  it "returns 404 for nonexisting file" do
    @uploaded_file.delete
    response = app.get(@uploaded_file.download_url)
    assert_equal 404,              response.status
    assert_equal "File Not Found", response.body_binary
    assert_equal "text/plain",     response.content_type
  end

  it "returns 404 for nonexisting storage" do
    url = @uploaded_file.download_url
    @shrine.storages.delete(@uploaded_file.storage_key)
    response = app.get(url)
    assert_equal 404,              response.status
    assert_equal "File Not Found", response.body_binary
    assert_equal "text/plain",     response.content_type
  end

  it "adds :host to the URL" do
    @shrine.plugin :download_endpoint, host: "http://example.com"
    assert_match %r{http://example\.com/\S+}, @uploaded_file.download_url
  end

  it "adds :prefix to the URL" do
    @shrine.plugin :download_endpoint, prefix: "attachments"
    assert_match %r{/attachments/\S+}, @uploaded_file.download_url
  end

  it "adds :host and :prefix to the URL" do
    @shrine.plugin :download_endpoint, host: "http://example.com", prefix: "attachments"
    assert_match %r{http://example\.com/attachments/\S+}, @uploaded_file.download_url
  end

  it "allows specifying :host per URL" do
    @shrine.plugin :download_endpoint, host: "http://foo.com"
    assert_match %r{http://bar\.com/\S+}, @uploaded_file.download_url(host: "http://bar.com")
  end

  it "accepts ad-hoc options" do
    app = Rack::TestApp.wrap(@shrine.download_endpoint(disposition: "attachment"), { Rack::SERVER_PROTOCOL => "HTTP/1.1" })
    response = app.get(@uploaded_file.download_url)
    assert_match /^attachment; /, response.headers[CONTENT_DISPOSITION_HEADER]
  end

  it "returns same URL regardless of metadata order" do
    @uploaded_file.data["metadata"] = { "filename" => "a", "mime_type" => "b", "size" => "c" }
    url1 = @uploaded_file.url
    @uploaded_file.data["metadata"] = { "mime_type" => "b", "size" => "c", "filename" => "a" }
    url2 = @uploaded_file.url
    assert_equal url1, url2
  end

  it "returns 400 on invalid serialized file" do
    response = app.get("/dontwork")
    assert_equal 400, response.status
    assert_equal "Invalid serialized file", response.body_binary

    response = app.get("/dont%20work")
    assert_equal 400, response.status
    assert_equal "Invalid serialized file", response.body_binary
  end

  describe "Shrine.download_response" do
    it "works in the main app" do
      @shrine.plugin :download_endpoint, prefix: "attachments"

      download_uri = URI.parse(@uploaded_file.download_url)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => download_uri.path,
        "QUERY_STRING"   => download_uri.query,
        "rack.input"     => StringIO.new,
      }

      status, headers, body = @shrine.download_response(env)

      assert_equal 200,                      status
      assert_equal @uploaded_file.size.to_s, headers[CONTENT_LENGTH_HEADER]
      assert_equal @uploaded_file.read,      body.enum_for(:each).to_a.join

      assert_equal "",                env["SCRIPT_NAME"]
      assert_equal download_uri.path, env["PATH_INFO"]
    end

    it "works in a mounted app" do
      @shrine.plugin :download_endpoint, prefix: "attachments"

      download_uri = URI.parse(@uploaded_file.download_url)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "/foo",
        "PATH_INFO"      => download_uri.path,
        "QUERY_STRING"   => download_uri.query,
        "rack.input"     => StringIO.new,
      }

      status, headers, body = @shrine.download_response(env)

      assert_equal 200,    status
      assert_equal "/foo", env["SCRIPT_NAME"]
    end

    it "accepts additional options" do
      @shrine.plugin :download_endpoint, prefix: "attachments"

      download_uri = URI.parse(@uploaded_file.download_url)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => download_uri.path,
        "QUERY_STRING"   => download_uri.query,
        "rack.input"     => StringIO.new,
      }

      status, headers, body = @shrine.download_response(env, disposition: "attachment")

      assert_equal 200,             status
      assert_match /^attachment; /, headers[CONTENT_DISPOSITION_HEADER]
    end

    it "fails when request path doesn't start with prefix" do
      @shrine.plugin :download_endpoint, prefix: "attachments"

      download_uri = URI.parse(@uploaded_file.download_url)

      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => download_uri.path.sub(/^\/attachments/, ""),
        "QUERY_STRING"   => download_uri.query,
        "rack.input"     => StringIO.new,
      }

      assert_raises(Shrine::Error) do
        @shrine.download_response(env)
      end
    end
  end

  it "defines #inspect and #to_s" do
    assert_equal "#<#{@shrine}::DownloadEndpoint>", endpoint.inspect
    assert_equal "#<#{@shrine}::DownloadEndpoint>", endpoint.to_s
  end
end
