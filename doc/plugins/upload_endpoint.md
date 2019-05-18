# Upload Endpoint

The [`upload_endpoint`][upload_endpoint] plugin provides a Rack endpoint which
accepts file uploads and forwards them to specified storage. On the client side
it's recommended to use [Uppy] for asynchronous uploads.

```rb
plugin :upload_endpoint
```

The plugin adds a `Shrine.upload_endpoint` method which, given a storage
identifier, returns a Rack application that accepts multipart POST requests,
and uploads received files to the specified storage. You can run this Rack
application inside your app:

```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount ImageUploader.upload_endpoint(:cache) => "/images/upload"
end
```

Asynchronous upload is typically meant to replace the caching phase in the
default synchronous workflow, so we want the uploads to go to temporary
(`:cache`) storage.

The above will create a `POST /images/upload` endpoint, which uploads the file
received in the `file` param using `ImageUploader`, and returns a JSON
representation of the uploaded file.

```rb
# POST /images/upload
{
  "id": "43kewit94.jpg",
  "storage": "cache",
  "metadata": {
    "size": 384393,
    "filename": "nature.jpg",
    "mime_type": "image/jpeg"
  }
}
```

This JSON string can now be assigned to an attachment attribute instead of a
raw file. In a form it can be written to a hidden attachment field, and then it
can be assigned as the attachment.

## Calling from a controller

If you want to run additional code around the upload (such as authentication),
mounting the upload endpoint in your router might be limiting. You can instead
create a custom controller action and handle upload requests there using
`Shrine.upload_response`:

```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  post "/images/upload", to: "uploads#image"
end
```
```rb
# app/controllers/uploads_controller.rb (Rails)
class UploadsController < ApplicationController
  def image
    # ... we can perform authentication here ...

    set_rack_response ImageUploader.upload_response(:cache, env)
  end

  private

  def set_rack_response((status, headers, body))
    self.status = status
    self.headers.merge!(headers)
    self.response_body = body
  end
end
```

## Limiting filesize

It's good practice to limit the accepted filesize of uploaded files. You can do
that with the `:max_size` option:

```rb
plugin :upload_endpoint, max_size: 20*1024*1024 # 20 MB
```

If the uploaded file is larger than the specified value, a `413 Payload Too
Large` response will be returned.

## Checksum

If you want the upload endpoint to verify the integrity of the uploaded file,
you can include the `Content-MD5` header in the request filled with the
base64-encoded MD5 hash of the file that was calculated prior to the upload,
and the endpoint will automatically use it to verify the uploaded data.

If the checksums don't match, a `460 Checksum Mismatch` response is returned.

## Context

The upload context will *not* contain `:record` and `:name` values, as the
upload happens independently of a database record. The endpoint will send the
following upload context:

* `:action` – holds the value `:upload`
* `:request` – holds an instance of `Rack::Request`

You can update the upload context via `:upload_context`:

```rb
plugin :upload_endpoint, upload_context: -> (request) do
  { location: "my-location" }
end
```

## Upload

You can also customize the upload itself via the `:upload` option:

```rb
plugin :upload_endpoint, upload: -> (io, context, request) do
  Shrine.new(:cache).upload(io, context)
end
```

## Response

The response returned by the endpoint can be customized via the
`:rack_response` option:

```rb
plugin :upload_endpoint, rack_response: -> (uploaded_file, request) do
  body = { data: uploaded_file.data, url: uploaded_file.url }.to_json
  [201, { "Content-Type" => "application/json" }, [body]]
end
```

## Ad-hoc options

You can override any of the options above when creating the endpoint/response:

```rb
Shrine.upload_endpoint(:cache, max_size: 20*1024*1024)
# or
Shrine.upload_response(:cache, env, max_size: 20*1024*1024)
```

[upload_endpoint]: /lib/shrine/plugins/upload_endpoint.rb
[Uppy]: https://uppy.io
