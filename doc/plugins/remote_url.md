---
title: Remote URL
---

The [`remote_url`][remote_url] plugin allows you to attach files from a remote
location.

```rb
plugin :remote_url, max_size: 20*1024*1024
```

## Usage

The plugin will add the `#<name>_remote_url` writer to your model, which
downloads the remote file and uploads it to temporary storage.

```rb
photo.image_remote_url = "http://example.com/cool-image.png"
photo.image.mime_type         #=> "image/png"
photo.image.size              #=> 43423
photo.image.original_filename #=> "cool-image.png"
```

If you're using `Shrine::Attacher` directly, you can use
`Attacher#assign_remote_url`:

```rb
attacher.assign_remote_url("http://example.com/cool-image.png")
attacher.file.mime_type         #=> "image/png"
attacher.file.size              #=> 43423
attacher.file.original_filename #=> "cool-image.png"
```

## Downloader

By default, the file will be downloaded using `Down.download` from the [Down]
gem. This will use the [Down::NetHttp] backend by default, which is a wrapper
around [open-uri].

You can pass options to the downloader via the `:downloader` option:

```rb
attacher.assign_remote_url(url, downloader: { 'Authorization' => 'Basic ...' })
```

You can also change the downloader:

```rb
# Gemfile
gem "http"
```
```rb
require "down/http"

plugin :remote_url, downloader: -> (url, **options) {
  Down::Http.download(url, **options) do |client|
    client.follow(max_hops: 2).timeout(connect: 2, read: 2)
  end
}
```

Any `Down::NotFound` and `Down::TooLarge` exceptions will be rescued and
converted into validation errors. If you want to convert any other exceptions
into validation errors, you can raise them as
`Shrine::Plugins::RemoteUrl::DownloadError`:

```rb
plugin :remote_url, downloader: -> (url, **options) {
  begin
    RestClient.get(url)
  rescue RestClient::ExceptionWithResponse => error
    raise Shrine::Plugins::RemoteUrl::DownloadError, "remote file not found"
  end
}
```

### Calling downloader

You can call the downloader directly with `Shrine.remote_url`:

```rb
# or YourUploader.remote_url(...)
file = Shrine.remote_url("https://example.com/image.jpg")
file #=> #<Tempfile:...>
```

You can pass additional options as well:

```rb
# or YourUploader.remote_url(...)
Shrine.remote_url("https://example.com/image.jpg", headers: { "Cookie" => "..." })
```

## Uploader options

Any additional options passed to `Attacher#assign_remote_url` will be forwarded
to `Attacher#assign` (and `Shrine#upload`):

```rb
attacher.assign_remote_url(url, metadata: { "mime_type" => "text/plain" })
```

## Maximum size

It's a good practice to limit the maximum filesize of the remote file:

```rb
plugin :remote_url, max_size: 20*1024*1024 # 20 MB
```

Now if a file that is bigger than 20MB is assigned, download will be terminated
as soon as it gets the "Content-Length" header, or the size of currently
downloaded content surpasses the maximum size. However, if for whatever reason
you don't want to limit the maximum file size, you can set `:max_size` to nil:

```rb
plugin :remote_url, max_size: nil
```

## Errors

If download errors, the error is rescued and a validation error is added equal
to the error message. You can change the default error message:

```rb
plugin :remote_url, error_message: "download failed"
plugin :remote_url, error_message: -> (url, error) { I18n.t("errors.download_failed") }
```

## Background

If you want the file to be downloaded from the URL in the background, you can
use the [shrine-url] storage which allows you to assign a custom URL as cached
file ID, and pair that with the `backgrounding` plugin.

## File extension

When attaching from a remote URL, the uploaded file location will inherit the
extension from the URL. However, some URLs might not have an extension. To
handle this case, you can use the `infer_extension` plugin to infer the
extension from the MIME type.

```rb
plugin :infer_extension
```

## Instrumentation

If the `instrumentation` plugin has been loaded, the `remote_url` plugin adds
instrumentation around remote URL downloading.

```rb
# instrumentation plugin needs to be loaded *before* remote_url
plugin :instrumentation
plugin :remote_url
```

Downloading remote URLs will trigger a `remote_url.shrine` event with the
following payload:

| Key                 | Description                            |
| :--                 | :----                                  |
| `:remote_url`       | The remote URL string                  |
| `:download_options` | Any download options passed in         |
| `:uploader`         | The uploader class that sent the event |

A default log subscriber is added as well which logs these events:

```plaintext
Remote URL (1550ms) – {:remote_url=>"https://example.com/image.jpg",:download_options=>{},:uploader=>Shrine}
```

You can also use your own log subscriber:

```rb
plugin :remote_url, log_subscriber: -> (event) {
  Shrine.logger.info JSON.generate(name: event.name, duration: event.duration, **event.payload)
}
```
```plaintext
{"name":"remote_url","duration":5,"remote_url":"https://example.com/image.jpg","download_options":{},"uploader":"Shrine"}
```

Or disable logging altogether:

```rb
plugin :remote_url, log_subscriber: nil
```

[remote_url]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/remote_url.rb
[Down]: https://github.com/janko/down
[Down::NetHttp]: https://github.com/janko/down#downnethttp
[open-uri]: https://ruby-doc.org/stdlib/libdoc/open-uri/rdoc/OpenURI.html
[http.rb]: https://github.com/httprb/http
[shrine-url]: https://github.com/shrinerb/shrine-url
