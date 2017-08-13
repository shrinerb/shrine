require "test_helper"
require "shrine/plugins/download_endpoint"
require "rack/test_app"

describe Shrine::Plugins::DownloadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(@uploader.class::DownloadEndpoint))
  end

  before do
    @uploader = uploader do
      plugin :download_endpoint, storages: [:cache, :store], prefix: nil
    end
  end

  it "returns file contents in the response" do
    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = app.get(uploaded_file.url)
    assert_equal uploaded_file.read, response.body_binary
  end

  it "returns file contents when opened IO responds to #each_chunk" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.storage.instance_eval do
      def open(*)
        io = super
        io.instance_eval { def each_chunk; yield read; end }
        io
      end
    end
    response = app.get(uploaded_file.url)
    assert_equal "content", response.body_binary
  end

  it "returns Content-Length with filesize" do
    uploaded_file = @uploader.upload(fakeio("content"))
    response = app.get(uploaded_file.url)
    assert_equal "7", response.headers["Content-Length"]

    uploaded_file.metadata.delete("size")
    response = app.get(uploaded_file.url)
    assert_equal "7", response.headers["Content-Length"]
  end

  it "returns Content-Type with MIME type" do
    uploaded_file = @uploader.upload(fakeio(content_type: "text/plain"))
    response = app.get(uploaded_file.url)
    assert_equal "text/plain", response.headers["Content-Type"]

    uploaded_file = @uploader.upload(fakeio(filename: "plain.txt"))
    response = app.get(uploaded_file.url)
    assert_equal "text/plain", response.headers["Content-Type"]

    uploaded_file = @uploader.upload(fakeio)
    response = app.get(uploaded_file.url)
    assert_equal "application/octet-stream", response.headers["Content-Type"]

    uploaded_file = @uploader.upload(fakeio(filename: "foo.foo"))
    response = app.get(uploaded_file.url)
    assert_equal "application/octet-stream", response.headers["Content-Type"]
  end

  it "returns Content-Disposition with filename" do
    uploaded_file = @uploader.upload(fakeio(filename: "plain.txt"))
    response = app.get(uploaded_file.url)
    assert_equal "inline; filename=\"plain.txt\"", response.headers["Content-Disposition"]

    uploaded_file = @uploader.upload(fakeio)
    response = app.get(uploaded_file.url)
    assert_equal "inline; filename=\"#{uploaded_file.id}\"", response.headers["Content-Disposition"]

    @uploader.class.plugin :download_endpoint, disposition: "attachment"
    uploaded_file = @uploader.upload(fakeio)
    response = app.get(uploaded_file.url)
    assert_equal "attachment; filename=\"#{uploaded_file.id}\"", response.headers["Content-Disposition"]
  end

  it "closes the downloaded file" do
    uploaded_file = @uploader.upload(fakeio)
    StringIO.any_instance.expects(:close)
    response = app.get(uploaded_file.url)
    response.body_binary # for body to be read
  end

  it "returns 404 for nonexisting storage" do
    uploaded_file = @uploader.upload(fakeio)
    @uploader.class.storages.delete(uploaded_file.storage_key.to_sym)
    response = app.get(uploaded_file.url)
    assert_equal 404, response.status
    assert_equal "File Not Found", response.body_binary
    assert_equal "text/plain", response.content_type
  end

  it "adds :host to the URL" do
    @uploader.class.plugin :download_endpoint, host: "http://example.com"
    uploaded_file = @uploader.upload(fakeio)
    assert_match %r{http://example.com/\S+}, uploaded_file.url
  end

  it "adds :prefix to the URL" do
    @uploader.class.plugin :download_endpoint, prefix: "attachments"
    uploaded_file = @uploader.upload(fakeio)
    assert_match %r{/attachments/\S+}, uploaded_file.url
  end

  it "adds :host and :prefix to the URL" do
    @uploader.class.plugin :download_endpoint, host: "http://example.com", prefix: "attachments"
    uploaded_file = @uploader.upload(fakeio)
    assert_match %r{http://example.com/attachments/\S+}, uploaded_file.url
  end

  it "returns regular URL for non-selected storages" do
    @uploader.class.plugin :download_endpoint, storages: []
    uploaded_file = @uploader.upload(fakeio)
    assert_match /#{uploaded_file.id}$/, uploaded_file.url
  end

  it "supports legacy URLs" do
    uploaded_file = @uploader.upload(fakeio)
    response = app.get("/#{uploaded_file.storage_key}/#{uploaded_file.id}")
    assert_equal uploaded_file.read, response.body_binary
  end

  it "makes the endpoint inheritable" do
    endpoint1 = Class.new(@uploader.class)::DownloadEndpoint
    endpoint2 = Class.new(@uploader.class)::DownloadEndpoint
    refute_equal endpoint1, endpoint2
  end
end
