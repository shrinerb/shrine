require "test_helper"
require "shrine/plugins/download_endpoint"
require "rack/test_app"

describe Shrine::Plugins::DownloadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(@uploader.class::DownloadEndpoint))
  end

  before do
    @uploader = uploader do
      plugin :download_endpoint, storages: [:store], prefix: nil
    end
    @uploaded_file = @uploader.upload(fakeio("image", filename: "foo.jpg"))
    @id = @uploaded_file.id
  end

  describe "app" do
    it "returns file contents in the response" do
      response = app.get "/store/#{@id}"
      assert_equal "image", response.body_binary
      assert_equal "5", response.headers["Content-Length"]
    end

    it "returns file contents when opened IO responds to #each_chunk" do
      @uploader.storage.instance_eval do
        def open(*)
          io = super
          io.instance_eval { def each_chunk; yield read; end }
          io
        end
      end
      response = app.get "/store/#{@id}"
      assert_equal "image", response.body_binary
      assert_equal "5", response.headers["Content-Length"]
    end

    it "returns the inline content disposition by default" do
      response = app.get "/store/#{@id}"
      assert_match /inline; filename="\w+\.jpg"/, response.headers["Content-Disposition"]
    end

    it "returns the attachment content disposition when set" do
      @uploader.opts[:download_endpoint_disposition] = "attachment"
      response = app.get "/store/#{@id}"
      assert_match /attachment; filename="\w+\.jpg"/, response.headers["Content-Disposition"]
    end

    it "returns the correct content type" do
      response = app.get "/store/#{@id}"
      assert_equal "image/jpeg", response.headers["Content-Type"]
    end

    it "returns octet-stream content type by default" do
      @id = @uploader.upload(fakeio("image", filename: "foo.foo")).id
      response = app.get "/store/#{@id}"
      assert_equal "application/octet-stream", response.headers["Content-Type"]

      @id = @uploader.upload(fakeio("image")).id
      response = app.get "/store/#{@id}"
      assert_equal "application/octet-stream", response.headers["Content-Type"]
    end

    it "closes the downloaded file" do
      StringIO.any_instance.expects(:close)
      response = app.get "/store/#{@id}"
      response.body_binary # for body to be read
    end

    it "refuses storages which are not allowed" do
      response = app.get "/cache/#{@id}"
      assert_http_error 403, response
    end

    it "refuses storages which are nonexistent" do
      response = app.post "/nonexistent/#{@id}"
      assert_http_error 403, response
    end
  end

  describe "#url" do
    it "returns the endpoint URL" do
      uploaded_file = @uploader.upload(fakeio, location: "foo.jpg")
      assert_equal "/store/foo.jpg", uploaded_file.url
    end

    it "applies the host" do
      @uploader.opts[:download_endpoint_host] = "http://example.com"
      uploaded_file = @uploader.upload(fakeio, location: "foo.jpg")
      assert_equal "http://example.com/store/foo.jpg", uploaded_file.url
    end

    it "applies the prefix" do
      @uploader.opts[:download_endpoint_prefix] = "attachments"
      uploaded_file = @uploader.upload(fakeio, location: "foo.jpg")
      assert_equal "/attachments/store/foo.jpg", uploaded_file.url
    end

    it "applies the host and prefix" do
      @uploader.opts[:download_endpoint_host] = "http://example.com"
      @uploader.opts[:download_endpoint_prefix] = "attachments"
      uploaded_file = @uploader.upload(fakeio, location: "foo.jpg")
      assert_equal "http://example.com/attachments/store/foo.jpg", uploaded_file.url
    end

    it "returns default for uploaded files which aren't in the list" do
      uploaded_file = @uploader.class.new(:cache).upload(fakeio, location: "foo.jpg")
      refute_equal "/cache/foo.jpg", uploaded_file.url
    end
  end

  it "makes the endpoint inheritable" do
    endpoint1 = Class.new(@uploader.class)::DownloadEndpoint
    endpoint2 = Class.new(@uploader.class)::DownloadEndpoint
    refute_equal endpoint1, endpoint2
  end

  def assert_http_error(status, response)
    assert_equal status, response.status
    assert_equal "application/json", response.headers["Content-Type"]
    refute_empty response.body_json.fetch("error")
  end
end
