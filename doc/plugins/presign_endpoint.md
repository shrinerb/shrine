# Presign Endpoint

The `presign_endpoint` plugin provides a Rack endpoint which generates the URL,
fields, and headers that can be used to upload files directly to a storage
service. On the client side it's recommended to use [Uppy] for asynchronous
uploads. Storage services that support direct uploads include [Amazon S3],
[Google Cloud Storage], [Microsoft Azure Storage] and more.

```rb
plugin :presign_endpoint
```

The plugin adds a `Shrine.presign_endpoint` method which, given a storage
identifier, returns a Rack application that accepts GET requests and generates
a presign for the specified storage. You can run this Rack application inside
your app:

```rb
# config.ru (Rack)
map "/images/presign" do
  run ImageUploader.presign_endpoint(:cache)
end

# OR

# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount ImageUploader.presign_endpoint(:cache) => "/images/presign"
end
```

Asynchronous upload is typically meant to replace the caching phase in the
default synchronous workflow, so we want to generate parameters for uploads to
the temporary (`:cache`) storage.

The above will create a `GET /images/presign` endpoint, which calls `#presign`
on the storage and returns the HTTP verb, URL, params, and headers needed for a
single upload directly to the storage service, in JSON format.

```rb
# GET /images/presign
{
  "method": "post",
  "url": "https://my-bucket.s3-eu-west-1.amazonaws.com",
  "fields": {
    "key": "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    "policy": "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb25kaXRpb25zIjpbeyJidWNrZXQiOiJ...",
    "x-amz-credential": "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    "x-amz-algorithm": "AWS4-HMAC-SHA256",
    "x-amz-date": "20151024T001129Z",
    "x-amz-signature": "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
  },
  "headers": {}
}
```

## Location

By default the generated location won't have any file extension, but you can
specify one by sending the `filename` query parameter:

```
GET /images/presign?filename=nature.jpg
```

It's also possible to customize how the presign location is generated:

```rb
plugin :presign_endpoint, presign_location: -> (request) do
  "#{SecureRandom.hex}/#{request.params["filename"]}"
end
```

## Options

Some storages accept additional presign options, which you can pass in via
`:presign_options`, here is an example for S3 storage:

```rb
plugin :presign_endpoint, presign_options: -> (request) do
  # Uppy will send the "filename" and "type" query parameters
  filename = request.params["filename"]
  type     = request.params["type"]

  {
    content_length_range: 0..(10*1024*1024),                  # limit filesize to 10MB
    content_disposition: ContentDisposition.inline(filename), # download with original filename
    content_type:        type,                                # set correct content type
  }
end
```

The example above uses the [content_disposition] gem to correctly format the
`Content-Disposition` header value.

The `:presign_options` can be a Proc or a Hash.

## Presign

You can also customize how the presign itself is generated via the `:presign`
option:

```rb
plugin :presign_endpoint, presign: -> (id, options, request) do
  # return a Hash with :url, :fields, and :headers keys
end
```

## Response

The response returned by the endpoint can be customized via the
`:rack_response` option:

```rb
plugin :presign_endpoint, rack_response: -> (data, request) do
  body = { endpoint: data[:url], params: data[:fields], headers: data[:headers] }.to_json
  [201, { "Content-Type" => "application/json" }, [body]]
end
```

## Ad-hoc options

You can override any of the options above when creating the endpoint:

```rb
Shrine.presign_endpoint(:cache, presign_location: "${filename}")
```

[Uppy]: https://uppy.io
[Amazon S3]: https://aws.amazon.com/s3/
[Google Cloud Storage]: https://cloud.google.com/storage/
[Microsoft Azure Storage]: https://azure.microsoft.com/en-us/services/storage/
[content_disposition]: https://github.com/shrinerb/content_disposition
