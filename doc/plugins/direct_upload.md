# Direct Upload

*[OBSOLETE] This plugin is obsolete, you should use `upload_endpoint` or
`presign_endpoint` plugins instead.*

The `direct_upload` plugin provides a Rack endpoint which can be used for
uploading individual files asynchronously. It requires the [Roda] gem.

```rb
plugin :direct_upload
```

The Roda endpoint provides two routes:

* `POST /:storage/upload`
* `GET /:storage/presign`

This first route is for doing direct uploads to your app, the received file
will be uploaded the underlying storage. The second route is for doing direct
uploads to a 3rd-party service, it will return the URL where the file can be
uploaded to, along with the necessary request parameters.

This is how you can mount the endpoint in a Rails application:

```rb
Rails.application.routes.draw do
  mount ImageUploader::UploadEndpoint => "/images"
end
```

Now your application will get `POST /images/cache/upload` and `GET
/images/cache/presign` routes. On the client side it is recommended to use
[Uppy] for uploading files to the app or directly to the 3rd-party service.

## Uploads

The upload route accepts a "file" query parameter, and returns the uploaded
file in JSON format:

```rb
# POST /images/cache/upload
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

Once you've uploaded the file, you can assign the result to the hidden
attachment field in the form, or immediately send it to the server.

Note that the endpoint uploads the file standalone, without any knowledge of
the record, so `context[:record]` and `context[:name]` will be nil.

### Limiting filesize

It's good idea to limit the maximum filesize of uploaded files, if you set the
`:max_size` option, files which are too big will get automatically deleted and
413 status will be returned:

```rb
plugin :direct_upload, max_size: 5*1024*1024 # 5 MB
```

Note that this option doesn't affect presigned uploads, there you can apply
filesize limit when generating a presign. The filesize constraint here is for
security purposes, you should still perform file validations on attaching.

## Presigns

The presign route returns the URL to the 3rd-party service to which you can
upload the file, along with the necessary query parameters.

```rb
# GET /images/cache/presign
{
  "url" => "https://my-bucket.s3-eu-west-1.amazonaws.com",
  "fields" => {
    "key" => "b7d575850ba61b44c8a9ff889dfdb14d88cdc25f8dd121004c8",
    "policy" => "eyJleHBpcmF0aW9uIjoiMjAxNS0QwMToxMToyOVoiLCJjb2...",
    "x-amz-credential" => "AKIAIJF55TMZYT6Q/20151024/eu-west-1/s3/aws4_request",
    "x-amz-algorithm" => "AWS4-HMAC-SHA256",
    "x-amz-date" => "20151024T001129Z",
    "x-amz-signature" => "c1eb634f83f96b69bd675f535b3ff15ae184b102fcba51e4db5f4959b4ae26f4"
  }
}
```

If you want that the generated location includes a file extension, you can
specify the `extension` query parameter: `GET
/:storage/presign?extension=.png`.

You can also completely change how the key is generated, with
`:presign_location`:

```rb
plugin :direct_upload, presign_location: -> (request) { "${filename}" }
```

This presign route internally calls `#presign` on the storage, and many
storages accept additional service-specific options. You can generate these
additional options per-request through `:presign_options`:

```rb
plugin :direct_upload, presign_options: { acl: "public-read" }

plugin :direct_upload, presign_options: ->(request) do
  filename = request.params["filename"]
  content_type = Rack::Mime.mime_type(File.extname(filename))

  {
    content_length_range: 0..(10*1024*1024),                     # limit filesize to 10MB
    content_disposition: "attachment; filename=\"#{filename}\"", # download with original filename
    content_type:        content_type,                           # set correct content type
  }
end
```

Both `:presign_location` and `:presign_options` in their block versions are
yielded an instance of [Roda request], which is a subclass of `Rack::Request`.

See the [Direct Uploads to S3] guide for further instructions on how to hook
the presigned uploads to a form.

## Allowed storages

By default only uploads to `:cache` are allowed, to prevent the possibility of
having orphan files in your main storage. But you can allow more storages:

```rb
plugin :direct_upload, allowed_storages: [:cache, :store]
```

## Customizing endpoint

Since the endpoint is a [Roda] app, it is very customizable. For example, you
can add a Rack middleware to change the response status and headers:

```rb
class ShrineUploadMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    result = @app.call(env)

    if result[0] == 200 && env["PATH_INFO"].end_with?("upload")
      result[0] = 201
      result[1]["Location"] = Shrine.uploaded_file(result[2].first).url
    end

    result
  end
end

Shrine::UploadEndpoint.use ShrineUploadMiddleware
```

Upon subclassing uploader the upload endpoint is also subclassed. You can also
call the plugin again in an uploader subclass to change its configuration.

[Roda]: https://github.com/jeremyevans/roda
[Uppy]: https://uppy.io
[Roda request]: http://roda.jeremyevans.net/rdoc/classes/Roda/RodaPlugins/Base/RequestMethods.html
[Direct Uploads to S3]: /doc/direct_s3.md#readme
