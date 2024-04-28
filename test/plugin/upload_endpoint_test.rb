require "test_helper"
require "shrine/plugins/upload_endpoint"
require "http/form_data"
require "rack/test"
require "json"

describe Shrine::Plugins::UploadEndpoint do
  def app
    Rack::Test::Session.new(Rack::Lint.new(endpoint))
  end

  def endpoint
    @shrine.upload_endpoint(:cache)
  end

  def rack_file(filename: nil)
    Rack::Test::UploadedFile.new(image.path, "image/jpeg", original_filename: filename)
  end

  before do
    @uploader = uploader { plugin :upload_endpoint }
    @shrine = @uploader.class
  end

  it "returns a JSON response" do
    response = app.post "/", { file: rack_file }

    assert_equal 200, response.status
    assert_equal "application/json; charset=utf-8", response.headers["Content-Type"]

    result = JSON.parse(response.body)

    assert_match /^\w+\.jpg$/, result["id"]
    assert_equal "cache",      result["storage"]
    assert_equal image.size,   result["metadata"]["size"]
    assert_equal "image.jpg",  result["metadata"]["filename"]
    assert_equal "image/jpeg", result["metadata"]["mime_type"]
  end

  it "uploads the file" do
    response = app.post "/", { file: rack_file }
    uploaded_file = @shrine.uploaded_file(response.body)
    assert_equal image.read, uploaded_file.read
  end

  it "finds the file in Uppy's default files[] format" do
    response = app.post "/", { "files[]": rack_file }
    uploaded_file = @shrine.uploaded_file(JSON.parse(response.body))
    assert_equal image.read, uploaded_file.read
  end

  it "doesn't accept more than one file" do
    response = app.post "/", { "files[]": [rack_file, rack_file] }
    assert_equal 400, response.status
    assert_equal "Too Many Files", response.body
  end

  it "accepts already wrapped uploaded file (Rails)" do
    Rack::Request.any_instance.stubs(:params).returns({ "file" => fakeio("file") })

    response = app.post "/", { file: rack_file }

    assert_equal 200,    response.status
    assert_equal "file", @shrine.uploaded_file(JSON.parse(response.body)).read
  end

  it "validates maximum size" do
    @shrine.plugin :upload_endpoint, max_size: 10
    response = app.post "/", { file: rack_file }
    assert_equal 413, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Too Large", response.body
  end

  it "validates that param is a file" do
    response = app.post "/", { file: "image" }, multipart: true
    assert_equal 400, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Not Valid", response.body
  end

  it "validates that param is present" do
    response = app.post "/", { image: "image" }, multipart: true
    assert_equal 400, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Upload Not Found", response.body
  end

  it "handles filenames with UTF-8 characters" do
    filename = "über_pdf_with_1337%_leetness.pdf"
    response = app.post "/", { file: rack_file(filename: filename) }
    assert_equal 200, response.status
    uploaded_file = @shrine.uploaded_file(response.body)
    assert_equal filename, uploaded_file.original_filename
  end

  it "adds the :action parameter to context" do
    @shrine.class_eval { def extract_metadata(io, context); { "action" => context[:action] }; end }
    response = app.post "/", { file: rack_file }
    assert_equal "upload", JSON.parse(response.body)["metadata"]["action"]
  end

  it "accepts upload context" do
    @shrine.plugin :upload_endpoint, upload_context: -> (r) { { location: "foo" } }
    response = app.post "/", { file: rack_file }
    assert_equal "foo", JSON.parse(response.body)["id"]
    uploaded_file = @shrine.uploaded_file(response.body)
    assert_equal image.read, uploaded_file.read
  end

  it "accepts upload proc" do
    @shrine.plugin :upload_endpoint, upload: -> (i, c, r) { @uploader.upload(i, **c, location: "foo") }
    response = app.post "/", { file: rack_file }
    assert_equal "foo", JSON.parse(response.body)["id"]
    uploaded_file = @shrine.uploaded_file(response.body)
    assert_equal image.read, uploaded_file.read
  end

  it "accepts :url parameter" do
    @shrine.plugin :upload_endpoint, url: true
    response = app.post "/", { file: rack_file }
    uploaded_file = @shrine.uploaded_file(JSON.parse(response.body)["data"])
    assert_equal uploaded_file.url, JSON.parse(response.body)["url"]

    @shrine.plugin :upload_endpoint, url: { foo: "bar" }, upload_context: -> (r) { { location: "foo" } }
    @shrine.storages[:cache].expects(:url).with("foo", { foo: "bar" }).returns("my-url")
    response = app.post "/", { file: rack_file }
    assert_equal "my-url", JSON.parse(response.body)["url"]

    @shrine.plugin :upload_endpoint, url: -> (f, r) { "my-url" }
    response = app.post "/", { file: rack_file }
    assert_equal "my-url", JSON.parse(response.body)["url"]
  end

  it "verifies provided checksum" do
    response = app.post "/", { file: rack_file }, { "HTTP_CONTENT_MD5" => Digest::MD5.base64digest(image.read) }
    assert_equal 200, response.status

    response = app.post "/", { file: rack_file }, { "HTTP_CONTENT_MD5" => Digest::MD5.base64digest("") }
    assert_equal 460, response.status
    assert_equal "The Content-MD5 you specified did not match what was recieved", response.body

    response = app.post "/", { file: rack_file }, { "HTTP_CONTENT_MD5" => "foo" }
    assert_equal 400, response.status
    assert_equal "The Content-MD5 you specified was invalid", response.body
  end

  it "accepts response proc" do
    @shrine.plugin :upload_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/vnd.api+json"}, [{data: o}.to_json]]
    end
    response = app.post "/", { file: rack_file }
    assert_equal ["id", "storage", "metadata"], JSON.parse(response.body)["data"].keys
    assert_equal "application/vnd.api+json", response.headers["Content-Type"]
  end

  it "allows overriding options when instantiating the endpoint" do
    app = Rack::Test::Session.new(@shrine.upload_endpoint(:cache, max_size: 10))
    response = app.post "/", { file: rack_file }
    assert_equal 413, response.status
  end

  it "doesn't react to parseable Content-Type" do
    response = app.post "/", {}, { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
    assert_equal 400, response.status
    assert_equal "Upload Not Found", response.body
  end

  it "doesn't react to blank Content-Type" do
    response = app.post "/", {}, { "CONTENT_TYPE" => "" }
    assert_equal 400, response.status
    assert_equal "Upload Not Found", response.body
  end

  it "accepts only POST requests" do
    response = app.put "/", { file: rack_file }
    assert_equal 405, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Method Not Allowed", response.body
  end

  it "accepts only root requests" do
    response = app.post "/upload", { file: rack_file }
    assert_equal 404, response.status
  end

  describe "Shrine.upload_response" do
    it "returns the Rack response triple" do
      form_data = HTTP::FormData.create({
        file: HTTP::FormData::Part.new("content", filename: "foo.txt")
      })

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
      form_data = HTTP::FormData.create({
        file: HTTP::FormData::Part.new("content", filename: "foo.txt")
      })

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
end
