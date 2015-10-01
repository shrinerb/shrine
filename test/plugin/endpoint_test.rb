require "test_helper"
require "json"

describe "endpoint plugin" do
  include TestHelpers::Rack

  def app
    @uploader.class.endpoint
  end

  def image
    Rack::Test::UploadedFile.new(image_path)
  end

  def setup
    @uploader = uploader(:cache) { plugin :endpoint }
  end

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

    assert_equal '{"name":"avatar","phase":"endpoint"}', body['id']
  end

  it "assigns metadata" do
    image = Rack::Test::UploadedFile.new("test/fixtures/image.jpg", "image/jpeg")
    post "/cache/avatar", file: image

    metadata = body.fetch('metadata')
    assert_equal 'image.jpg', metadata['filename']
    assert_equal 'image/jpeg', metadata['content_type']
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

  it "accepts only POST requests" do
    put "/cache/avatar", file: image

    assert_equal 404, response.status
  end

  it "refuses storages which are not allowed" do
    post "/store/avatar", file: image

    assert_http_error 403
  end

  it "refuses storages which are nonexistent" do
    post "/nonexistent/avatar", file: image

    assert_http_error 403
  end

  it "returns appropriate error message for missing file" do
    post "/cache/avatar"

    assert_http_error 400
  end

  it "returns appropriate error message for invalid file" do
    post "/cache/avatar", file: "foo"

    assert_http_error 400
  end

  it "refuses files which are too big" do
    @uploader = uploader(:cache) { plugin :endpoint, max_size: 0 }
    post "/cache/avatar", file: image
    assert_http_error 413

    @uploader.opts[:endpoint_max_size] = 5 * 1024 * 1024
    post "/cache/avatar", file: image
    assert_equal 200, response.status
  end

  it "allows other errors to propagate" do
    @uploader.class.class_eval do
      def process(io, context)
        raise
      end
    end

    assert_raises(RuntimeError) { post "/cache/avatar", file: image }
  end

  it "memoizes the endpoint" do
    assert_equal @uploader.class.endpoint, @uploader.class.endpoint
  end

  def assert_http_error(status)
    assert_equal status, response.status
    assert_equal "application/json", response.headers["Content-Type"]
    refute_empty body.fetch("error")
  end
end
