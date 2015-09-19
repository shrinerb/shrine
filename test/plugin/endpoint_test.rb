require "test_helper"

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

    assert @uploader.storage.exists?(body["id"])
  end

  test "passes in the :name parameter as context" do
    @uploader.class.class_eval do
      def generate_location(io, context)
        context.fetch(:name).to_s
      end
    end

    post "/cache/avatar", file: image

    assert_equal 'avatar', body['id']
  end

  test "assigns metadata" do
    image = Rack::Test::UploadedFile.new("test/fixtures/image.jpg", "image/jpeg")
    post "/cache/avatar", file: image

    metadata = body.fetch('metadata')
    assert_equal 'image.jpg', metadata['filename']
    assert_equal 'image/jpeg', metadata['content_type']
    assert_kind_of Integer, metadata['size']
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

  test "allows other errors to propagate" do
    @uploader.class.plugin :processing, storage: :cache, processor: proc { raise }

    assert_raises(RuntimeError) { post "/cache/avatar", file: image }
  end

  test "endpoint is memoized" do
    assert_equal @uploader.class.endpoint, @uploader.class.endpoint
  end

  test "works with processing versions" do
    @uploader.class.plugin :processing, storage: :cache, versions: true,
      processor: ->(io, context) { Hash[reverse: io] }

    post "/cache/avatar", file: image

    refute_empty body.fetch("reverse")
  end

  test "throws error when storage doesn't exist" do
    assert_raises(Shrine::Error) do
      uploader { plugin :endpoint, allowed_storages: [:foo] }
    end
  end
end
