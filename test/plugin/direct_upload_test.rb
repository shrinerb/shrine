require "test_helper"
require "json"
require "shrine/storage/s3"

describe "the direct_upload plugin" do
  include TestHelpers::Rack

  def app
    @uploader.class.direct_endpoint
  end

  def image
    Rack::Test::UploadedFile.new(image_path)
  end

  def setup
    @uploader = uploader(:cache) { plugin :direct_upload, max_size: nil }
  end

  describe "POST /:storage/:name" do
    it "returns a JSON response" do
      post "/cache/avatar", file: image

      assert_equal 200, response.status
      assert_equal "application/json", response.headers["Content-Type"]
      JSON.parse(response.body)
    end

    it "uploads the given file" do
      post "/cache/avatar", file: image

      assert @uploader.storage.exists?(body["id"])
    end

    it "passes in :name and :phase parameters as context" do
      @uploader.class.class_eval do
        def generate_location(io, context)
          context.to_json
        end
      end

      post "/cache/avatar", file: image

      assert_equal '{"name":"avatar","phase":"cache"}', body['id']
    end

    it "assigns metadata" do
      image = Rack::Test::UploadedFile.new("test/fixtures/image.jpg", "image/jpeg")
      post "/cache/avatar", file: image

      metadata = body.fetch('metadata')
      assert_equal 'image.jpg', metadata['filename']
      assert_equal 'image/jpeg', metadata['mime_type']
      assert_kind_of Integer, metadata['size']
    end

    it "serializes uploaded hashes and arrays as well" do
      uploaded_file = @uploader.upload(fakeio)

      @uploader.class.class_eval { define_method(:upload) { |*| Hash[thumb: uploaded_file] } }
      post "/cache/avatar", file: image
      refute_empty body.fetch('thumb')

      @uploader.class.class_eval { define_method(:upload) { |*| Array[uploaded_file] } }
      post "/cache/avatar", file: image
      refute_empty body.fetch(0)
    end

    it "refuses files which are too big" do
      @uploader.opts[:direct_upload_max_size] = 0
      post "/cache/avatar", file: image
      assert_http_error 413

      @uploader.opts[:direct_upload_max_size] = 5 * 1024 * 1024
      post "/cache/avatar", file: image
      assert_equal 200, response.status
    end

    it "accepts only POST requests" do
      put "/cache/avatar", file: image

      assert_equal 404, response.status
    end

    it "returns appropriate error message for missing file" do
      post "/cache/avatar"

      assert_http_error 400
    end

    it "returns appropriate error message for invalid file" do
      post "/cache/avatar", file: "foo"

      assert_http_error 400
    end

    it "allows other errors to propagate" do
      @uploader.class.class_eval do
        def process(io, context)
          raise
        end
      end

      assert_raises(RuntimeError) { post "/cache/avatar", file: image }
    end

    it "doesn't exist if :presign was set" do
      @uploader.opts[:direct_upload_presign] = true
      post "/cache/avatar"

      assert_equal 404, last_response.status
    end
  end

  describe "GET /:storage/presign" do
    before do
      @uploader.class.storages[:cache] = Shrine::Storage::S3.new(
        bucket:            "foo",
        region:            "eu-west-1",
        access_key_id:     "abc123",
        secret_access_key: "xyz123",
      )
      @uploader.opts[:direct_upload_presign] = true
    end

    it "returns a presign object" do
      get "/cache/presign"

      refute_empty body.fetch("url")
      refute_empty body.fetch("fields")
    end

    it "accepts an extension" do
      get "/cache/presign?extension=.jpg"

      assert_match /\.jpg$/, body["fields"].fetch("key")
    end

    it "applies options passed to configuration" do
      @uploader.opts[:direct_upload_presign] = ->(r) do
        {content_type: r.params["content_type"]}
      end
      get "/cache/presign?content_type=image/jpeg"

      assert_equal "image/jpeg", body["fields"].fetch("Content-Type")
    end

    it "allows the configuration block to return nil" do
      @uploader.opts[:direct_upload_presign] = ->(r) { nil }
      get "/cache/presign"

      assert_equal 200, last_response.status
    end

    it "doesn't exist if :presign wasn't set" do
      @uploader.opts[:direct_upload_presign] = false
      get "cache/presign"

      assert_equal 404, last_response.status
    end
  end

  it "refuses storages which are not allowed" do
    post "/store/avatar", file: image

    assert_http_error 403
  end

  it "refuses storages which are nonexistent" do
    post "/nonexistent/avatar", file: image

    assert_http_error 403
  end

  it "memoizes the endpoint" do
    assert_equal @uploader.class.direct_endpoint, @uploader.class.direct_endpoint
  end

  def assert_http_error(status)
    assert_equal status, response.status
    assert_equal "application/json", response.headers["Content-Type"]
    refute_empty body.fetch("error")
  end
end
