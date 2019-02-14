# Data URI

The [`data_uri`][data_uri] plugin enables you to upload files as [data URIs].
This plugin is useful for example when using [HTML5 Canvas].

```rb
plugin :data_uri
```

If your attachment is called "avatar", this plugin will add `#avatar_data_uri`
and `#avatar_data_uri=` methods to your model.

```rb
user.avatar #=> nil
user.avatar_data_uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
user.avatar #=> #<Shrine::UploadedFile>

user.avatar.mime_type         #=> "image/png"
user.avatar.size              #=> 43423
```

You can also use `#data_uri=` and `#data_uri` methods directly on the
`Shrine::Attacher` (which the model methods just delegate to):

```rb
attacher.data_uri = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
```

If the data URI wasn't correctly parsed, an error message will be added to the
attachment column. You can change the default error message:

```rb
plugin :data_uri, error_message: "data URI was invalid"
plugin :data_uri, error_message: ->(uri) { I18n.t("errors.data_uri_invalid") }
```

## File extension

A data URI doesn't convey any information about the file extension, so when
attaching from a data URI, the uploaded file location will be missing an
extension. If you want the upload location to always have an extension, you can
load the `infer_extension` plugin to infer it from the MIME type.

```rb
plugin :infer_extension
```

## `Shrine.data_uri`

If you just want to parse the data URI and create an IO object from it, you can
do that with `Shrine.data_uri`. If the data URI cannot be parsed, a
`Shrine::Plugins::DataUri::ParseError` will be raised.

```rb
# or YourUploader.data_uri("...")
io = Shrine.data_uri("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA")
io.content_type #=> "image/png"
io.size         #=> 21
io.read         # decoded content
```

When the content type is ommited, `text/plain` is assumed. The parser also
supports raw data URIs which aren't base64-encoded.

```rb
# or YourUploader.data_uri("...")
io = Shrine.data_uri("data:,raw%20content")
io.content_type #=> "text/plain"
io.size         #=> 11
io.read         #=> "raw content"
```

You can also assign a filename:

```rb
io = Shrine.data_uri("data:,content", filename: "foo.txt")
io.original_filename #=> "foo.txt"
```

## `UploadedFile#data_uri` and `UploadedFile#base64`

This plugin also adds UploadedFile#data_uri method, which returns a
base64-encoded data URI of the file content, and UploadedFile#base64, which
simply returns the file content base64-encoded.

```rb
uploaded_file.data_uri #=> "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUA"
uploaded_file.base64   #=> "iVBORw0KGgoAAAANSUhEUgAAAAUA"
```

[data_uri]: /lib/shrine/plugins/data_uri.rb
[data URIs]: https://tools.ietf.org/html/rfc2397
[HTML5 Canvas]: https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API
