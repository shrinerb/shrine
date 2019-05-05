# Remote URL

The [`remote_url`][remote_url] plugin allows you to attach files from a remote
location.

```rb
plugin :remote_url, max_size: 20*1024*1024
```

If for example your attachment is called "avatar", this plugin will add
`#avatar_remote_url` and `#avatar_remote_url=` methods to your model.

```rb
user.avatar #=> nil
user.avatar_remote_url = "http://example.com/cool-image.png"
user.avatar #=> #<Shrine::UploadedFile>

user.avatar.mime_type         #=> "image/png"
user.avatar.size              #=> 43423
user.avatar.original_filename #=> "cool-image.png"
```

You can also use `#remote_url=` and `#remote_url` methods directly on the
`Shrine::Attacher`:

```rb
attacher.remote_url = "http://example.com/cool-image.png"
```

The file will by default be downloaded using [Down], which is a wrapper around
the `open-uri` standard library. Note that Down expects the given URL to be
URI-encoded.

## Dynamic options

You can dynamically pass options to the downloader by using
`Attacher#assign_remote_url`:

```rb
attacher.assign_remote_url(url, downloader: { 'Authorization' => 'Basic ...' })
```

You can also pass any other `Shrine#upload` options:

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

## Custom downloader

If you want to customize how the file is downloaded, you can override the
`:downloader` parameter and provide your own implementation. For example, you
can use the HTTP.rb Down backend for downloading:

```rb
require "down/http"

plugin :remote_url, max_size: 20*1024*1024, downloader: -> (url, max_size:, **options) do
  Down::Http.download(url, max_size: max_size, **options) do |http|
    http.follow(max_hops: 2).timeout(connect: 2, read: 2)
  end
end
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

When attaching from a remote URL, the uploaded file location will have the
extension inferred from the URL. However, some URLs might not have an
extension, in which case the uploaded file location also won't have the
extension. If you want the upload location to always have an extension, you can
load the `infer_extension` plugin to infer it from the MIME type.

```rb
plugin :infer_extension
```

[remote_url]: /lib/shrine/plugins/remote_url.rb
[Down]: https://github.com/janko/down
[shrine-url]: https://github.com/shrinerb/shrine-url
