require "test_helper"
require "minitest/mock"

class EndpointTest < Minitest::Test
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

  test "returns a JSON response" do
    post "/cache/avatar", file: image

    assert_equal 200, response.status
    assert_equal "application/json", response.headers["Content-Type"]
    JSON.parse(response.body)
  end

  test "uploads the given file" do
    post "/cache/avatar", file: image

    assert @uploader.storage.exists?(body["data"]["id"])
  end

  test "passes in the :name parameter as context" do
    @uploader.class.class_eval do
      def generate_location(io, context)
        context.fetch(:name).to_s
      end
    end

    post "/cache/avatar", file: image

    assert_equal 'avatar', body['data']['id']
  end

  test "assigns metadata" do
    image = Rack::Test::UploadedFile.new("test/fixtures/image.jpg", "image/jpeg")
    post "/cache/avatar", file: image

    metadata = body['data'].fetch('metadata')
    assert_equal 'image.jpg', metadata['filename']
    assert_equal 'image/jpeg', metadata['content_type']
    assert_kind_of Integer, metadata['size']
  end

  test "serializes uploaded hashes and arrays as well" do
    uploaded_file = @uploader.upload(fakeio)

    @uploader.class.class_eval { define_method(:upload) { |*| Hash[thumb: uploaded_file] } }
    post "/cache/avatar", file: image
    refute_empty body.fetch('thumb')

    @uploader.class.class_eval { define_method(:upload) { |*| Array[uploaded_file] } }
    post "/cache/avatar", file: image
    refute_empty body.fetch(0)
  end

  test "returns url of :return_url is passed in" do
    @uploader = uploader(:cache) { plugin :endpoint, return_url: true }
    post "/cache/avatar", file: image

    refute_empty body.fetch("url")
  end

  test "accepts only POST requests" do
    put "/cache/avatar", file: image

    assert_equal 404, response.status
  end

  test "refuses storages which are not allowed" do
    post "/store/avatar", file: image

    assert_equal 403, response.status
    refute_empty body.fetch("error")

    post "/nonexistent/avatar", file: image

    assert_equal 403, response.status
    refute_empty body.fetch("error")
  end

  test "returns appropriate error message for missing file" do
    post "/cache/avatar"

    assert_equal 400, response.status
    refute_empty body.fetch("error")
  end

  test "returns appropriate error message for invalid file" do
    post "/cache/avatar", file: "foo"

    assert_equal 400, response.status
    refute_empty body.fetch("error")
  end

  test "refuses files which are too big" do
    @uploader = uploader(:cache) { plugin :endpoint, max_size: 0 }
    post "/cache/avatar", file: image
    assert_equal 413, response.status
    refute_empty body.fetch("error")

    @uploader.opts[:endpoint_max_size] = 5 * 1024 * 1024
    post "/cache/avatar", file: image
    assert_equal 200, response.status
  end

  test "allows other errors to propagate" do
    @uploader.class.plugin :processing, storage: :cache, processor: proc { raise }

    assert_raises(RuntimeError) { post "/cache/avatar", file: image }
  end

  test "endpoint is memoized" do
    assert_equal @uploader.class.endpoint, @uploader.class.endpoint
  end
end
