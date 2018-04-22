require "test_helper"
require "shrine/plugins/upload_endpoint"
require "rack/test_app"
require "json"

describe Shrine::Plugins::UploadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(endpoint))
  end

  def endpoint
    @uploader.class.upload_endpoint(:cache)
  end

  before do
    @uploader = uploader { plugin :upload_endpoint }
  end

  it "returns a JSON response" do
    response = app.post "/", multipart: {file: image}
    assert_equal 200, response.status
    assert_equal "application/json", response.headers["Content-Type"]
    refute_empty               response.body_json["id"]
    assert_equal "cache",      response.body_json["storage"]
    assert_equal image.size,   response.body_json["metadata"]["size"]
    assert_equal "image.jpg",  response.body_json["metadata"]["filename"]
    assert_equal "image/jpeg", response.body_json["metadata"]["mime_type"]
  end

  it "uploads the file" do
    response = app.post "/", multipart: {file: image}
    uploaded_file = @uploader.class.uploaded_file(response.body_json)
    assert_equal image.read, uploaded_file.read
  end

  it "validates maximum size" do
    @uploader.class.plugin :upload_endpoint, max_size: 10
    response = app.post "/", multipart: {file: image}
    assert_equal 413, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Too Large", response.body_binary
  end

  it "validates that param is a file" do
    response = app.post "/", multipart: {file: "image"}
    assert_equal 400, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Not Found", response.body_binary
  end

  it "validates that param is present" do
    response = app.post "/", multipart: {image: "image"}
    assert_equal 400, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Not Found", response.body_binary
  end

  it "adds the :action parameter to context" do
    @uploader.class.class_eval { def extract_metadata(io, context); {"action" => context[:action]}; end }
    response = app.post "/", multipart: {file: image}
    assert_equal "upload", response.body_json["metadata"]["action"]
  end

  it "adds the :request parameter to context" do
    @uploader.class.class_eval { def extract_metadata(io, context); {"query" => context[:request].query_string}; end }
    response = app.post "/?foo=bar", multipart: {file: image}
    assert_equal "foo=bar", response.body_json["metadata"]["query"]
  end

  it "accepts upload context" do
    @uploader.class.plugin :upload_endpoint, upload_context: -> (r) { { location: "foo" } }
    response = app.post "/", multipart: {file: image}
    assert_equal "foo", response.body_json["id"]
    uploaded_file = @uploader.class.uploaded_file(response.body_json)
    assert_equal image.read, uploaded_file.read
  end

  it "accepts upload proc" do
    @uploader.class.plugin :upload_endpoint, upload: -> (i, c, r) { @uploader.upload(i, c.merge(location: "foo")) }
    response = app.post "/", multipart: {file: image}
    assert_equal "foo", response.body_json["id"]
    uploaded_file = @uploader.class.uploaded_file(response.body_json)
    assert_equal image.read, uploaded_file.read
  end

  it "verifies provided checksum" do
    response = app.post "/", multipart: {file: image}, headers: {"Content-MD5" => Digest::MD5.base64digest(image.read)}
    assert_equal 200, response.status

    response = app.post "/", multipart: {file: image}, headers: {"Content-MD5" => Digest::MD5.base64digest("")}
    assert_equal 460, response.status
    assert_equal "The Content-MD5 you specified did not match what was recieved", response.body_binary

    response = app.post "/", multipart: {file: image}, headers: {"Content-MD5" => "foo"}
    assert_equal 400, response.status
    assert_equal "The Content-MD5 you specified was invalid", response.body_binary
  end

  it "accepts response proc" do
    @uploader.class.plugin :upload_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/vnd.api+json"}, [{data: o}.to_json]]
    end
    response = app.post "/", multipart: {file: image}
    assert_equal ["id", "storage", "metadata"], JSON.parse(response.body_binary)["data"].keys
    assert_equal "application/vnd.api+json", response.headers["Content-Type"]
  end

  it "allows overriding options when instantiating the endpoint" do
    app = Rack::TestApp.wrap(@uploader.class.upload_endpoint(:cache, max_size: 10))
    response = app.post "/", multipart: {file: image}
    assert_equal 413, response.status
  end

  it "doesn't react to parseable Content-Type" do
    response = app.post "/", headers: {"Content-Type" => "application/x-www-form-urlencoded"}
    assert_equal 400, response.status
    assert_equal "Upload Not Found", response.body_binary
  end

  it "doesn't react to blank Content-Type" do
    response = app.post "/", headers: {"Content-Type" => ""}
    assert_equal 400, response.status
    assert_equal "Upload Not Found", response.body_binary
  end

  it "accepts only POST requests" do
    response = app.put "/", multipart: {file: image}
    assert_equal 405, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Method Not Allowed", response.body_binary
  end

  it "accepts only root requests" do
    response = app.post "/upload", multipart: {file: image}
    assert_equal 404, response.status
  end
end
