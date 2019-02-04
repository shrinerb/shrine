# derivation_endpoint

The `derivation_endpoint` plugin provides a Rack app for dynamically processing
uploaded files on request. This allows you to create URLs to files that might
not have been generated yet, and have the endpoint process them on-the-fly.

## Quick start

We first load the plugin, providing a secret key and a path prefix to where the
endpoint will be mounted:

```rb
class ImageUploader < Shrine
  plugin :derivation_endpoint,
    secret_key: "<your-secret-key>",
    prefix:     "derivations/image"
end
```

We can then mount the derivation endpoint for our uploader into our app's
router on the path prefix we specified:

```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount ImageUploader.derivation_endpoint => "derivations/image"
end
```

Next we can define a "derivation" block for the type of processing we want to
apply to an attached file. For example, we can generate image thumbnails using
the [ImageProcessing] gem:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  # ...
  derivation :thumbnail do |file, width, height|
    ImageProcessing::MiniMagick
      .source(file)
      .resize_to_limit!(width.to_i, height.to_i)
  end
end
```

Now we can generate "derivation" URLs from attached files, which on request
will call the derivation block we defined.

```rb
photo.image.derivation_url(:thumbnail, "600", "400")
#=> "/derivations/image/thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

In this example, `photo` is an instance of a `Photo` model which has an `image`
attachment. The URL will render a `600x400` thumbnail of the original image.

## How it works

The `#derivation_url` method is defined on `Shrine::UploadedFile` objects. It
generates an URL consisting of the configured path prefix, derivation name and
arguments, serialized uploaded file, and an URL signature generated using the
configured secret key:

```
/  derivations/image  /  thumbnail  /  600/400  /  eyJmZvbyIb3JhZ2UiOiJzdG9yZSJ9  ?  signature=...
  └──── prefix ─────┘  └── name ──┘  └─ args ─┘  └─── serialized source file ───┘
```

When the derivation URL is requested, the derivation endpoint will first verify
the signature included in query params, and proceed only if it matches the
calculated signature. This ensures that only the server can generate valid
derivation URLs, preventing potential DoS attacks.

The derivation endpoint then extracts the source file data, derivation name and
arguments from the request URL, and calls the corresponding derivation block,
passing the downloaded source file and derivation arguments.

```rb
derivation :thumbnail do |file, arg1, arg2, ...|
  file #=> #<Tempfile:...> (source file downloaded to disk)
  arg1 #=> "600" (first derivation argument in #derivation_url)
  arg2 #=> "400" (second derivation argument in #derivation_url)

  # ... do processing ...

  # return result as a File/Tempfile object or String/Pathname path
end
```

The derivation block is expected to return the processed file is a
`File`/`Tempfile` object or a `String`/`Pathname` path. The resulting file is
then rendered in the HTTP response.

### Performance

By default, the processed file returned by the derivation block is not cached
anywhere. This means that repeated requests to the same derivation URL will
execute the derivation block each time, which can put a lot of load on your
application.

For this reason it's highly recommended to put a **CDN or other HTTP cache** in
front of your application. If you've configured a CDN, you can set the CDN host
at the plugin level, and it will be used for all derivation URLs:

```rb
plugin :derivation_endpoint, host: "https://your-dist-url.cloudfront.net"
```

Additionally, you can have the endpoint cache derivatives to a storage. With
this setup, the generated derivative will be uploaded to the storage on initial
request, and then on subsequent requests the derivative will be served directly
from the storage.

```rb
plugin :derivation_endpoint, upload: true
```

If you want to avoid having the endpoint directly serve the generated
derivatives, you can have the derivation response redirect to the uploaded
derivative on the storage service.

```rb
plugin :derivation_endpoint, upload: true, upload_redirect: true
```

For more details, see the "Uploading" section.

## Derivation response

Mounting the derivation endpoint into the app's router is the easiest way to
handle derivation requests, as routing and setting the response is done
automatically.

```rb
# config/routes.rb
Rails.application.routes.draw do
  mount ImageUploader.derivation_endpoint => "derivations/image"
end
```

However, this approach can also be limiting if one wants to perform additional
operations around derivation requests, such as authentication and
authorization.

Instead of mounting the endpoint into the router, you can also call the
derivation endpoint from a controller. In this case the endpoint needs to
receive the Rack env hash, so that it can infer derivation parameters from the
request URL. The return value is a 3-element array, containing the status,
headers, and body that should be returned in the HTTP response:

```rb
# config/routes.rb
Rails.application.routes.draw do
  get "/derivations/image/*rest" => "derivations#image"
end

# app/controllers/derivations_controller.rb
class DerivationsController < ApplicationController
  def image
    # we can perform authentication here
    set_rack_response ImageUploader.derivation_response(request.env)
  end

  private

  def set_rack_response((status, headers, body))
    self.status = status
    self.headers.merge!(headers)
    self.response_body = body
  end
end
```

For even more control, you can generate derivation responses in custom routes.
Once you retrieve the `Shrine::UploadedFile` object, you can call
`#derivation_response` directly on it, passing the derivation name and
arguments, as well as the Rack env hash.

```rb
# config/routes.rb
Rails.application.routes.draw do
  resources :photos do
    member do
      get "thumbnail" # for example
    end
  end
end

# app/controllers/photos_controller.rb
class PhotosController < ApplicationController
  def thumbnail
    # we can perform authorization here
    photo = Photo.find(params[:id])
    image = photo.image

    set_rack_response image.derivation_response(:thumbnail, 300, 300, env: request.env)
  end

  private

  def set_rack_response((status, headers, body))
    self.status = status
    self.headers.merge!(headers)
    self.response_body = body
  end
end
```

`Shrine.derivation_endpoint`, `Shrine.derivation_response`, and
`UploadedFile#derivation_response` methods all accept additional options, which
will override options set on the plugin level.

```rb
ImageUploader.derivation_endpoint(disposition: "attachment")
# or
ImageUploader.derivation_response(env, disposition: "attachment")
# or
uploaded_file.derivation_response(:thumbnail, env: env, disposition: "attachment")
```

## Dynamic settings

For most options passed to `plugin :derivation_endpoint`,
`Shrine.derivation_endpoint`, `Shrine.derivation_response`, or
`Shrine::UploadedFile#derivation_response`, the value to be a block that
returns a dynamic result. The block will be evaluated within the context of a
`Shrine::Derivation` instance, allowing you to access information about the
current derivation:

```rb
plugin :derivation_endpoint, disposition: -> {
  self   #=> #<Shrine::Derivation>

  name   #=> :thumbnail
  args   #=> ["500", "400"]
  source #=> #<Shrine::UploadedFile>

  # ...
}
```

For example, we can use it to specify that thumbnails should be rendered inline
in the browser, while other derivatives will be force downloaded.

```rb
plugin :derivation_endpoint, disposition: -> {
  name == :thumbnail ? "inline" : "attachment"
}
```

## Host

Derivation URLs are relative by default. To generate absolute URLs, you can
pass the `:host` option:

```rb
plugin :derivation_endpoint, host: "https://example.com"
```

Now the generated URLs will include the specified URL host:

```rb
uploaded_file.derivation_url(:thumbnail)
#=> "https://example.com/.../thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
```

You can also pass `:host` per URL:

```rb
uploaded_file.derivation_url(:thumbnail, host: "https://example.com")
#=> "https://example.com/.../thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
```

## Prefix

If you're mounting the derivation endpoint under a path prefix, the derivation
URLs will need to include that path prefix. This can be configured with the
`:prefix` option:

```rb
plugin :derivation_endpoint, prefix: "transformations/image"
```

Now generated URLs will include the specified path prefix:

```rb
uploaded_file.derivation_url(:thumbnail)
#=> ".../transformations/image/thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
```

You can also pass `:prefix` per URL:

```rb
uploaded_file.derivation_url(:thumbnail, prefix: "transformations/image")
#=> ".../transformations/image/thumbnail/eyJpZCI6ImZvbyIsInN?signature=..."
```

## Expiration

By default derivation URLs are valid indefinitely. If you want URLs to expire
after a certain amount of time, you can set the `:expires_in` option:

```rb
plugin :derivation_endpoint, expires_in: 90
```

Now any URL will stop being valid 90 seconds after it was generated:

```rb
uploaded_file.derivation_url(:thumbnail)
#=> ".../thumbnail/eyJpZCI6ImZvbyIsInN?expires_at=1547843568&signature=..."
```

You can also pass `:expires_in` per URL:

```rb
uploaded_file.derivation_url(:thumbnail, expires_in: 90)
#=> ".../thumbnail/eyJpZCI6ImZvbyIsInN?expires_at=1547843568&signature=..."
```

## Response headers

### Content Type

The derivation response includes the [`Content-Type`] header. By default
default its value will be inferred from the file extension of the derivative
(using `Rack::Mime`). This can be overriden with the `:type` option:

```rb
plugin :derivation_endpoint, type: -> { "image/webp" if name == :webp }
```

The above will set `Content-Type` response header value to `image/webp` for
`:webp` derivatives, while for others it will be inferred from the file
extension.

You can also set `:type` per URL:

```rb
uploaded_file.derivation_url(:webp, type: "image/webp")
#=> ".../webp/eyJpZCI6ImZvbyIsInN?type=image%2Fwebp&signature=..."
```

### Content Disposition

The derivation response includes the [`Content-Disposition`] header. By default
the disposition is set to `inline`, while the download filename is generated
from derivation name, arguments and source file id. These values can be changed
with the `:disposition` and `:filename` options:

```rb
plugin :derivation_endpoint,
  disposition: -> { name == :thumbnail ? "inline" : "attachment" },
  filename:    -> { [name, *args].join("-") }
```

With the above settings, visiting a thumbnail URL will render the image in the
browser, while other derivatives will be treated as an attachment and be
downloaded.

The `:filename` and `:disposition` options can also be set per URL:

```rb
uploaded_file.derivation_url(:pdf, disposition: "attachment", filename: "custom-filename")
#=> ".../thumbnail/eyJpZCI6ImZvbyIsInN?disposition=attachment&filename=custom-filename&signature=..."
```

### Cache Control

The endpoint uses the [`Cache-Control`] response header to tell clients
(browsers, CDNs, HTTP caches) how long they can cache derivation responses. The
default cache duration is 1 year since the initial request. This can be changed
with the `:cache_control` option:

```rb
plugin :derivation_endpoint, cache_control: { max_age: 7*24*60*60 } # 7 weeks
# Cache-Control: public, max-age=604800
```

It's also possible to modify any other `Cache-Control` directives:

```rb
plugin :derivation_endpoint, cache_control: { public: false, private: true }
# Cache-Control: private, max-age=31536000
```

Note that `Cache-Control` is added to response headers only when using
`Shrine.derivation_endpoint` or `Shrine.derivation_response`, it's not added
when using `Shrine::UploadedFile#derivation_response`.

## Uploading

By default the generated derivatives aren't saved anywhere, which means that
repeated requests to the same derivation URL will call the derivation block
each time. If you don't want to rely on solely on your HTTP cache, you can
enable the `:upload` option, which will make derivatives automatically cached
on the Shrine storage:

```rb
plugin :derivation_endpoint, upload: true
```

Now whenever a derivation is requested, the endpoint will first check whether
the derivative already exists on the storage. If it doesn't exist, it will
fetch the original uploaded file, call the derivation block, upload the
derivative to the storage, and serve the derivative. If the derivative does
exist on checking, the endpoint will download the derivative and serve it.

The default upload location for derivatives is `<source id>/<name>-<args>`.
This can be changed with the `:upload_location` option:

```rb
plugin :derivation_endpoint, upload: true, upload_location: -> {
  # e.g. "derivatives/9a7d1bfdad24a76f9cfaff137fe1b5c7/thumbnail-1000-800"
  ["derivatives", File.basename(source.id, ".*"), [name, *args].join("-")].join("/")
}
```

Since the default upload location won't have any file extension, the derivation
response won't know the appropriate `Content-Type` header value to set, and the
generic `application/octet-stream` will be used. It's recommended to use the
`:type` option to set the appropriate `Content-Type` value.

The target storage used is the same as for the source uploaded file. The
`:upload_storage` option can be used to specify a different Shrine storage:

```rb
plugin :derivation_endpoint, upload: true,
                             upload_storage: :thumbnail_storage
```

Additional storage-specific upload options can be passed via `:upload_options`:

```rb
plugin :derivation_endpoint, upload: true,
                             upload_options: { acl: "public-read" }
```

### Redirecting

You can configure the endpoint to redirect to the uploaded derivative on the
storage instead of serving it through the endpoint (which is the default
behaviour) by setting both `:upload` and `:upload_redirect` to `true`:

```rb
plugin :derivation_endpoint, upload: true,
                             upload_redirect: true
```

In that case additional storage-specific URL options can be passed in for the
redirect URL:

```rb
plugin :derivation_endpoint, upload: true,
                             upload_redirect: true,
                             upload_redirect_url_options: { public: true }
```

## Cache busting

The derivation endpoint response instructs browsers, CDNs and other clients to
cache the response for a long time. This saves server resources and improves
response times. However, if the derivation block is modified, the derivation
URLs will remain unchanged, which means that old cached derivatives might still
be served.

If you want to ensure derivation URLs don't point to old cached derivatives,
you can add a "version" query parameter to the URL, which will make HTTP caches
treat it as a new URL. You can do this via the `:version` option:

```rb
plugin :derivation_endpoint, version: -> { 1 if name == :thumbnail }
```

With the above settings, all `:thumbnail` derivation URLs will include
`version` in the query string:

```rb
uploaded_file.derivation_url(:thumbnail)
#=> ".../thumbnail/eyJpZCI6ImZvbyIsInN?version=1&signature=..."
```

You can also bump the `:version` per URL:

```rb
uploaded_file.derivation_url(:thumbnail, version: 1)
#=> ".../thumbnail/eyJpZCI6ImZvbyIsInN?version=1&signature=..."
```

## Accessing source file

If you want to access the source `UploadedFile` object when deriving, you can
set `:include_uploaded_file` to `true`.

```rb
plugin :derivation_endpoint, include_uploaded_file: true
```

Now the source `UploadedFile` will be passed as the second argument of the
derivation block:

```rb
derivation :thumbnail do |file, uploaded_file, width, height|
  uploaded_file             #=> #<Shrine::UploadedFile>
  uploaded_file.id          #=> "9a7d1bfdad24a76f9cfaff137fe1b5c7.jpg"
  uploaded_file.storage_key #=> "store"
  uploaded_file.metadata    #=> {}

  # ...
end
```

By default original metadata that were extracted on attachment won't be
available in the derivation block. This is because metadata we want to have
available would need to be serialized into the derivation URL, which would make
it longer. However, you can opt in for the metadata you need with the
`:metadata` option:

```rb
plugin :derivation_endpoint, metadata: ["filename", "mime_type"]
```

Now `filename` and `mime_type` metadata values will be available in the
derivation block:

```rb
derivation :thumbnail do |file, uploaded_file, width, height|
  uploaded_file.metadata #=>
  # {
  #  "filename" => "nature.jpg",
  #  "mime_type" => "image/jpeg"
  # }

  uploaded_file.original_filename #=> "nature.jpg"
  uploaded_file.mime_type         #=> "image/jpeg"

  # ...
end
```

## Downloading

When a derivation is requested, the original uploaded file will be downloaded
to disk before the derivation block is called. If you want to pass in
additional storage-specific download options, you can do so via
`:download_options`:

```rb
plugin :derivation_endpoint, download_options: {
  sse_customer_algorithm: "AES256",
  sse_customer_key:       "secret_key",
  sse_customer_key_md5:   "secret_key_md5",
}
```

If the source file has been deleted, the error the storage raises when
attempting to download it will be propagated by default. For
`Shrine.derivation_endpoint` and `Shrine.derivation_response` you can have
these errors converted to 404 responses by adding them to `:download_errors`:

```rb
plugin :derivation_endpoint, download_errors: [
  Errno::ENOENT,              # raised by Shrine::Storage::FileSystem
  Aws::S3::Errors::NoSuchKey, # raised by Shrine::Storage::S3
]
```

### Skipping download

If you for whatever reason you don't want the uploaded file to be downloaded to
disk for you, you can set `:download` to `false`.

```rb
plugin :derivation_endpoint, download: false
```

In this case the `UploadedFile` object is yielded to the derivation block
instead of the raw file:

```rb
derivation :thumbnail do |uploaded_file, width, height|
  uploaded_file #=> #<Shrine::UploadedFile>

  # ...
end
```

One use case for this is delegating processing to a 3rd-party service:

```rb
require "down/http"

derivation :thumbnail do |uploaded_file, width, height|
  # generate the thumbnail using ImageOptim.com
  Down::Http.download("https://im2.io/<USERNAME>/#{width}x#{height}/#{uploaded_file.url}")
end
```

## Derivation API

In addition to generating derivation responses, it's also possible to operate
with derivations on a lower level. You can access that API by calling
`UploadedFile#derivation`, which returns a `Derivation` object.

```rb
derivation = uploaded_file.derivation(:thumbnail, 500, 500)
derivation #=> #<Shrine::Derivation: @name=:thumbnail, @args=[500, 500] ...>
derivation.name   #=> :thumbnail
derivation.args   #=> [500, 500]
derivation.source #=> #<Shrine::UploadedFile>
```

When initializing the `Derivation` object you can override any plugin options:

```rb
uploaded_file.derivation(:grayscale, upload_storage: :other_storage)
```

### `#url`

`Derivation#url` method (called by `UploadedFile#derivation_url`) generates the
URL to the derivation.

```rb
derivation.url #=> "/thumbnail/500/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

### `#response`

`Derivation#response` method (called by `UploadedFile#derivation_response`)
generates appropriate status, headers, and body for the derivative to be
returned as an HTTP response.

```rb
status, headers, body = derivation.response
status  #=> 200
headers #=>
# {
#   "Content-Type" => "image/jpeg",
#   "Content-Length" => "12424",
#   "Content-Disposition" => "inline; filename=\"thumbnail-500-500-k9f8sdksdfk2414\"",
#   "Accept_Ranges" => "bytes"
# }
body    #=> #each object that yields derivative content
```

### `#processed`

`Derivation#processed` method returns the processed derivative. If `:upload` is
enabled, it returns an `UploadedFile` object pointing to the derivative,
processing and uploading the derivative if it hasn't been already.

```rb
uploaded_file = derivation.processed
uploaded_file    #=> #<Shrine::UploadedFile>
uploaded_file.id #=> "bcfd0d67e4a8ec2dc9a6d7ddcf3825a1/thumbnail-500-500"
```

### `#generate`

`Derivation#generate` method calls the derivation block and returns the result.

```rb
result = derivation.generate
result #=> #<Tempfile:...>
```

Internally it will download the source uploaded file to disk and pass it to the
derivation block (unless `:download` was disabled). You can also pass in an
already downloaded source file:

```rb
derivation.generate(source_file)
```

### `#upload`

`Derivation#upload` method uploads the given file to the configured derivation
location.

```rb
uploaded_file = derivation.upload(file)
uploaded_file    #=> #<Shrine::UploadedFile>
uploaded_file.id #=> "bcfd0d67e4a8ec2dc9a6d7ddcf3825a1/thumbnail-500-500"
```

If not given any arguments, it generates the derivative before uploading it.

### `#retrieve`

`Derivation#retrieve` method returns the uploaded derivative file. If the file
exists on the storage, it returns an `UploadedFile` object, otherwise `nil` is
returned.

```rb
uploaded_file = derivation.retrieve
uploaded_file    #=> #<Shrine::UploadedFile>
uploaded_file.id #=> "bcfd0d67e4a8ec2dc9a6d7ddcf3825a1/thumbnail-500-500"
```

### `#delete`

`Derivation#delete` method deletes the uploaded derivative file from the
storage.

```rb
derivation.delete
```

### `#option`

`Derivation#option` returns the value of the specified plugin option.

```rb
derivation.option(:upload_location)
#=> "bcfd0d67e4a8ec2dc9a6d7ddcf3825a1/thumbnail-500-500"
```

## Plugin Options

| Name                           | Description                                                                                                                                               |
| :----------------------------- | :----------                                                                                                                                               |
| `:cache_control`               | Hash of directives for the `Cache-Control` response header (default: `{ public: true, max_age: 365*24*60*60 }`)                                           |
| `:disposition`                 | Whether the browser should attempt to render the derivative (`inline`) or prompt the user to download the file to disk (`attachment`) (default: `inline`) |
| `:download`                    | Whether the source uploaded file should be downloaded to disk when the derivation block is called (default: `true`)                                       |
| `:download_errors`             | List of error classes that will be converted to a `404 Not Found` response by the derivation endpoint (default: `[]`)                                     |
| `:download_options`            | Additional options to pass when downloading the source uploaded file (default: `{}`)                                                                      |
| `:expires_in`                  | Number of seconds after which the URL will not be available anymore (default: `nil`)                                                                      |
| `:filename`                    | Filename the browser will assume when the derivative is downloaded to disk (default: `<name>-<args>-<source id basename>`)                                |
| `:host`                        | URL host to use when generated URLs (default: `nil`)                                                                                                      |
| `:include_uploaded_file`       | Whether to include the source uploaded file in the derivation block arguments (default: `false`)                                                          |
| `:metadata`                    | List of metadata keys the source uploaded file should include in the derivation block (default: `[]`)                                                     |
| `:prefix`                      | Path prefix added to the URLs (default: `nil`)                                                                                                            |
| `:secret_key`                  | Key used to sign derivation URLs in order to prevent tampering (required)                                                                                 |
| `:type`                        | Media type returned in the `Content-Type` response header in the derivation response (default: determined from derivative's extension)                    |
| `:upload`                      | Whether the generated derivatives will be cached on the storage (default: `false`)                                                                        |
| `:upload_location`             | Location to which the derivatives will be uploaded on the storage (default: `<source id>/<name>-<args>`)                                                  |
| `:upload_options`              | Additional options to be passed when uploading derivatives (default: `{}`)                                                                                |
| `:upload_redirect`             | Whether the derivation response should redirect to the uploaded derivative (default: `false`)                                                             |
| `:upload_redirect_url_options` | Additional options to be passed when generating the URL for the uploaded derivative (default: `{}`)                                                       |
| `:upload_storage`              | Storage to which the derivations will be uploaded (default: same storage as the source file)                                                              |
| `:version`                     | Version number to append to the URL for cache busting (default: `nil`)                                                                                    |

[ImageProcessing]: https://github.com/janko/image_processing
[`Content-Type`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
[`Content-Disposition`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Disposition
[`Cache-Control`]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control
