require "test_helper"
require "shrine/plugins/download_endpoint"
require "rack/test_app"

describe Shrine::Plugins::DownloadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(endpoint))
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
    assert_equal @uploaded_file.size.to_s, response.headers["Content-Length"]
    assert_equal @uploaded_file.mime_type, response.headers["Content-Type"]
    assert_equal ContentDisposition.inline(@uploaded_file.original_filename), response.headers["Content-Disposition"]
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
    assert_equal ContentDisposition.attachment(@uploaded_file.id), response.headers["Content-Disposition"]
  end

  it "returns Cache-Control" do
    response = app.get(@uploaded_file.download_url)
    assert_equal "max-age=31536000", response.headers["Cache-Control"]
  end

  it "accepts :redirect with true" do
    @shrine.plugin :download_endpoint, redirect: true
    response = app.get(@uploaded_file.download_url)
    assert_equal 302, response.status
    assert_match %r{^memory://\w+$}, response.headers["Location"]
  end

  it "accepts :redirect with proc" do
    @shrine.plugin :download_endpoint, redirect: -> (uploaded_file, request) { "/foo" }
    response = app.get(@uploaded_file.download_url)
    assert_equal 302, response.status
    assert_equal "/foo", response.headers["Location"]
  end

  it "returns Accept-Ranges" do
    response = app.get(@uploaded_file.download_url)
    assert_equal "bytes", response.headers["Accept-Ranges"]
  end

  it "supports ranged requests" do
    @uploaded_file = @uploader.upload(fakeio("content"))
    response = app.get(@uploaded_file.download_url, headers: { "Range" => "bytes=2-4" })
    assert_equal 206,           response.status
    assert_equal "bytes 2-4/7", response.headers["Content-Range"]
    assert_equal "3",           response.headers["Content-Length"]
    assert_equal "nte",         response.body_binary
  end

  it "returns ETag" do
    response = app.get(@uploaded_file.download_url)
    assert_instance_of String,    response.headers["ETag"]
    assert_match /^W\/"\w{32}"$/, response.headers["ETag"]
  end

  it "returns 404 for nonexisting file" do
    @uploaded_file.data["id"] = "nonexistent"
    response = app.get(@uploaded_file.download_url)
    assert_equal 404,              response.status
    assert_equal "File Not Found", response.body_binary
    assert_equal "text/plain",     response.content_type
  end

  it "returns 404 for nonexisting storage" do
    @uploaded_file.delete
    response = app.get(@uploaded_file.download_url)
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
    app = Rack::TestApp.wrap(@shrine.download_endpoint(disposition: "attachment"))
    response = app.get(@uploaded_file.download_url)
    assert_match /^attachment; /, response.headers["Content-Disposition"]
  end

  it "returns same URL regardless of metadata order" do
    @uploaded_file.data["metadata"] = { "filename" => "a", "mime_type" => "b", "size" => "c" }
    url1 = @uploaded_file.url
    @uploaded_file.data["metadata"] = { "mime_type" => "b", "size" => "c", "filename" => "a" }
    url2 = @uploaded_file.url
    assert_equal url1, url2
  end

  it "defines #inspect and #to_s" do
    assert_equal "#<#{@shrine}::DownloadEndpoint>", endpoint.inspect
    assert_equal "#<#{@shrine}::DownloadEndpoint>", endpoint.to_s
  end

  it "supports legacy URLs" do
    response = app.get("/#{@uploaded_file.storage_key}/#{@uploaded_file.id}")
    assert_equal @uploaded_file.read, response.body_binary
  end

  deprecated "adds DownloadEndpoint constant" do
    assert_respond_to @shrine::DownloadEndpoint, :call
  end
end
