# Infer Extension

The [`infer_extension`][infer_extension] plugin allows deducing the appropriate
file extension for the upload location based on the MIME type of the file. This
is useful when using `data_uri` and `remote_url` plugins, where the file
extension might not be known.

```rb
plugin :infer_extension
```

Ordinarily, the upload location will gain the inferred extension only if it
couldn't be determined from the filename. However, you can pass `force: true`
to force the inferred extension to be used rather than an extension from the
original filename. This can be used to canonicalize extensions (jpg, jpeg =>
jpeg), or replace an incorrect original extension.

```rb
plugin :infer_extension, force: true
```

By default `MIME::Types` will be used for inferring the extension, but you can
also choose a different inferrer:

```rb
plugin :infer_extension, inferrer: :mini_mime
```

The following inferrers are accepted:

| Name          | Description                                                                             |
| :------------ | :-----------                                                                            |
| `:mime_types` | (Default). Uses the [mime-types] gem to infer the appropriate extension from MIME type. |
| `:mini_mime`  | Uses the [mini_mime] gem to infer the appropriate extension from MIME type.             |

You can also define your own inferrer, with the possibility to call the
built-in inferrers:

```rb
plugin :infer_extension, inferrer: -> (mime_type, inferrers) do
  # don't add extension if the file is a text file
  inferrers[:rack_mime].call(mime_type) unless mime_type == "text/plain"
end
```

You can also use methods for inferring extension directly:

```rb
Shrine.infer_extension("image/jpeg")
# => ".jpeg"

Shrine.extension_inferrers[:mime_types].call("image/jpeg")
# => ".jpeg"
```

[infer_extension]: /lib/shrine/plugins/infer_extension.rb
[mime-types]: https://github.com/mime-types/ruby-mime-types
[mini_mime]: https://github.com/discourse/mini_mime
