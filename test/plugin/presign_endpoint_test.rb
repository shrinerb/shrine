require "test_helper"
require "shrine/plugins/presign_endpoint"
require "shrine/storage/s3"
require "rack/test_app"
require "json"

describe Shrine::Plugins::PresignEndpoint do
  def app
    Rack::TestApp.wrap(Rack::Lint.new(endpoint))
  end

  def endpoint
    @shrine.presign_endpoint(:cache)
  end

  before do
    @uploader = uploader { plugin :presign_endpoint }
    @shrine = @uploader.class
    @shrine.storages[:cache] = Shrine::Storage::S3.new(bucket: "foo", stub_responses: true)
  end

  it "returns a JSON response" do
    response = app.get "/"

    assert_equal 200, response.status

    assert_equal "application/json; charset=utf-8",  response.headers["Content-Type"]
    assert_equal response.body_binary.bytesize.to_s, response.headers["Content-Length"]
    assert_equal "no-store",                         response.headers["Cache-Control"]

    assert_instance_of String, response.body_json["method"]
    assert_instance_of String, response.body_json["url"]
    assert_instance_of Hash,   response.body_json["fields"]
    assert_instance_of Hash,   response.body_json["headers"]
  end

  it "uses extension from given filename" do
    response = app.get "/?filename=nature.jpg"
    assert_match /\.jpg$/, response.body_json["fields"]["key"]
  end

  it "accepts presign location" do
    @shrine.plugin :presign_endpoint, presign_location: -> (r) { "${filename}" }
    response = app.get "/"
    assert_match "${filename}", response.body_json["fields"]["key"]
  end

  it "accepts presign options" do
    @shrine.plugin :presign_endpoint, presign_options: { content_type: "image/jpeg" }
    response = app.get "/"
    assert_equal "image/jpeg", response.body_json["fields"]["Content-Type"]

    @shrine.plugin :presign_endpoint, presign_options: -> (r) { {content_type: "image/jpeg"} }
    response = app.get "/"
    assert_equal "image/jpeg", response.body_json["fields"]["Content-Type"]
  end

  it "accepts presign proc" do
    @shrine.plugin :presign_endpoint,
      presign_options: { content_type: "image/jpeg" },
      presign: -> (i, o, r) { {url: "foo", fields: o, headers: {"foo" => "bar"}} }
    response = app.get "/"
    assert_match "foo",        response.body_json["url"]
    assert_equal "image/jpeg", response.body_json["fields"]["content_type"]
    assert_equal "bar",        response.body_json["headers"]["foo"]
  end

  it "sets default fields and headers for presign" do
    @shrine.plugin :presign_endpoint,
      presign_options: { content_type: "image/jpeg" },
      presign: -> (i, o, r) { {url: "foo"} }
    response = app.get "/"
    assert_match "foo",    response.body_json["url"]
    assert_equal Hash.new, response.body_json["fields"]
    assert_equal Hash.new, response.body_json["headers"]
  end

  it "supports presign as an object that responds to #to_h" do
    @shrine.plugin :presign_endpoint,
      presign_options: { content_type: "image/jpeg" },
      presign: -> (i, o, r) { Struct.new(:url, :fields).new("foo", o) }
    response = app.get "/"
    assert_match "foo",        response.body_json["url"]
    assert_equal "image/jpeg", response.body_json["fields"]["content_type"]
    assert_equal Hash.new,     response.body_json["headers"]
  end

  it "accepts response proc" do
    @shrine.plugin :presign_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/vnd.api+json"}, [{data: o}.to_json]]
    end
    response = app.get "/"
    assert_equal ["fields", "headers", "method", "url"], JSON.parse(response.body_binary)["data"].keys.sort
    assert_equal "application/vnd.api+json", response.headers["Content-Type"]
  end

  it "allows overriding Cache-Control" do
    @shrine.plugin :presign_endpoint, rack_response: -> (o, r) do
      [200, {"Content-Type" => "application/json", "Cache-Control" => "no-cache"}, [o.to_json]]
    end
    response = app.get "/"
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  it "allows overriding options when instantiating the endpoint" do
    app = Rack::TestApp.wrap(@shrine.presign_endpoint(:cache, presign_options: { content_type: "image/jpeg" }))
    response = app.get "/"
    assert_equal "image/jpeg", response.body_json["fields"]["Content-Type"]
  end

  it "accepts only GET requests" do
    response = app.put "/"
    assert_equal 405, response.status
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Method Not Allowed", response.body_binary
  end

  it "accepts only root requests" do
    response = app.get "/presign"
    assert_equal 404, response.status
  end

  describe "Shrine.presign_response" do
    it "returns the Rack response triple" do
      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => "/s3/params",
        "QUERY_STRING"   => "filename=foo.txt",
        "rack.input"     => StringIO.new,
      }

      response = @shrine.presign_response(:cache, env)

      assert_equal 200, response[0]
      assert_equal "application/json; charset=utf-8", response[1]["Content-Type"]
      assert_match /\.txt$/, JSON.parse(response[2].first)["fields"]["key"]
    end

    it "accepts additional presign endpoint options" do
      env = {
        "REQUEST_METHOD" => "GET",
        "SCRIPT_NAME"    => "",
        "PATH_INFO"      => "/s3/params",
        "QUERY_STRING"   => "",
        "rack.input"     => StringIO.new,
      }

      response = @shrine.presign_response(:cache, env, presign_options: { content_type: "foo/bar" })

      assert_equal 200, response[0]
      assert_equal "application/json; charset=utf-8", response[1]["Content-Type"]
      assert_equal "foo/bar", JSON.parse(response[2].first)["fields"]["Content-Type"]
    end
  end

  it "defines #inspect and #to_s" do
    assert_equal "#<#{@shrine}::PresignEndpoint(:cache)>", endpoint.inspect
    assert_equal "#<#{@shrine}::PresignEndpoint(:cache)>", endpoint.to_s
  end
end
