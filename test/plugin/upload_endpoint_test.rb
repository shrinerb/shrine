require "test_helper"
require "shrine/plugins/upload_endpoint"
require "rack/test_app"
require "http/form_data"
require "json"

describe Shrine::Plugins::UploadEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(endpoint))
  end

  def endpoint
    @shrine.upload_endpoint(:cache)
  end

  before do
    @uploader = uploader { plugin :upload_endpoint }
    @shrine = @uploader.class
  end

  it "returns a JSON response" do
    response = app.post "/", multipart: {file: image}

    assert_equal 200, response.status
    assert_equal "application/json; charset=utf-8", response.headers["Content-Type"]

    assert_match /^\w+\.jpg$/, response.body_json["id"]
    assert_equal "cache",      response.body_json["storage"]
    assert_equal image.size,   response.body_json["metadata"]["size"]
    assert_equal "image.jpg",  response.body_json["metadata"]["filename"]
    assert_equal "image/jpeg", response.body_json["metadata"]["mime_type"]
  end

  it "uploads the file" do
    response = app.post "/", multipart: {file: image}
    uploaded_file = @shrine.uploaded_file(response.body_json)
    assert_equal image.read, uploaded_file.read
  end

  it "validates maximum size" do
    @shrine.plugin :upload_endpoint, max_size: 10
    response = app.post "/", multipart: {file: image}
    assert_equal 413, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Too Large", response.body_binary
  end

  it "validates that param is a file" do
    response = app.post "/", multipart: {file: "image"}
    assert_equal 400, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Not Valid", response.body_binary
  end

  it "validates that param is present" do
    response = app.post "/", multipart: {image: "image"}
    assert_equal 400, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Not Found", response.body_binary
  end

  it "handles filenames with UTF-8 characters" do
    filename = "über_pdf_with_1337%_leetness.pdf"
    form = HTTP::FormData.create(file: HTTP::FormData::Part.new("", filename: filename))
    response = app.post "/", multipart: {input: form.to_s}, headers: {"Content-Type" => form.content_type}
    assert_equal 200, response.status
    uploaded_file = @shrine.uploaded_file(response.body_json)
    assert_equal filename, uploaded_file.original_filename
  end

  it "adds the :action parameter to context" do
    @shrine.class_eval { def extract_metadata(io, context); {"action" => context[:action]}; end }
    response = app.post "/", multipart: {file: image}
    assert_equal "upload", response.body_json["metadata"]["action"]
  end

  it "adds the :request parameter to context" do
    @shrine.class_eval { def extract_metadata(io, context); {"query" => context[:request].query_string}; end }
    response = app.post "/?foo=bar", multipart: {file: image}
    assert_equal "foo=bar", response.body_json["metadata"]["query"]
  end

  it "accepts upload context" do
    @shrine.plugin :upload_endpoint, upload_context: -> (r) { { location: "foo" } }
    response = app.post "/", multipart: {file: image}
    assert_equal "foo", response.body_json["id"]
    uploaded_file = @shrine.uploaded_file(response.body_json)
    assert_equal image.read, uploaded_file.read
  end

  it "accepts upload proc" do
    @shrine.plugin :upload_endpoint, upload: -> (i, c, r) { @uploader.upload(i, c.merge(location: "foo")) }
    response = app.post "/", multipart: {file: image}
    assert_equal "foo", response.body_json["id"]
    uploaded_file = @shrine.uploaded_file(response.body_json)
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
    @shrine.plugin :upload_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/vnd.api+json"}, [{data: o}.to_json]]
    end
    response = app.post "/", multipart: {file: image}
    assert_equal ["id", "storage", "metadata"], JSON.parse(response.body_binary)["data"].keys
    assert_equal "application/vnd.api+json", response.headers["Content-Type"]
  end

  it "allows overriding options when instantiating the endpoint" do
    app = Rack::TestApp.wrap(@shrine.upload_endpoint(:cache, max_size: 10))
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

  describe "Shrine.upload_response" do
    it "returns the Rack response triple" do
      form_data = HTTP::FormData.create(
        file: HTTP::FormData::Part.new("content", filename: "foo.txt")
      )

      env = {
        "REQUEST_METHOD" => "POST",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => "/upload",
        "QUERY_STRING"   => "",
        "CONTENT_TYPE"   => form_data.content_type,
        "rack.input"     => StringIO.new(form_data.to_s),
      }

      response = @shrine.upload_response(:cache, env)

      assert_equal 200, response[0]
      assert_equal "application/json; charset=utf-8", response[1]["Content-Type"]
      assert_equal "content", @shrine.uploaded_file(response[2].first).read
    end

    it "accepts additional upload endpoint options" do
      form_data = HTTP::FormData.create(
        file: HTTP::FormData::Part.new("content", filename: "foo.txt")
      )

      env = {
        "REQUEST_METHOD" => "POST",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => "/upload",
        "QUERY_STRING"   => "",
        "CONTENT_TYPE"   => form_data.content_type,
        "rack.input"     => StringIO.new(form_data.to_s),
      }

      response = @shrine.upload_response(:cache, env, max_size: 1)

      assert_equal 413, response[0]
      assert_equal "text/plain", response[1]["Content-Type"]
      assert_equal "Upload Too Large", response[2].first
    end
  end

  it "defines #inspect and #to_s" do
    assert_equal "#<#{@shrine}::UploadEndpoint(:cache)>", endpoint.inspect
    assert_equal "#<#{@shrine}::UploadEndpoint(:cache)>", endpoint.to_s
  end

  deprecated "still defines Plugins::UploadEndpoint::App" do
    assert_equal @shrine::UploadEndpoint, @shrine::Plugins::UploadEndpoint::App
  end
end
