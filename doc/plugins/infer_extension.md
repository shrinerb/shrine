# Infer Extension

The [`infer_extension`][infer_extension] plugin allows deducing the appropriate
file extension for the upload location based on the MIME type of the file. This
is useful when using `data_uri` and `remote_url` plugins, where the file
extension might not be known.

```rb
plugin :infer_extension
```

## Inferrers

By default, the [mini_mime] gem will be used for inferring the extension, but
you can also choose a different inferrer:

```rb
plugin :infer_extension, inferrer: :mime_types
```

The following inferrers are accepted:

| Name          | Description                                                                            |
| :------------ | :-----------                                                                           |
| `:mini_mime`  | (Default). Uses the [mini_mime] gem to infer the appropriate extension from MIME type. |
| `:mime_types` | Uses the [mime-types] gem to infer the appropriate extension from MIME type.           |

You can also define your own inferrer, with the possibility to call the
built-in inferrers:

```rb
plugin :infer_extension, inferrer: -> (mime_type, inferrers) do
  # don't add extension if the file is a text file
  inferrers[:mini_mime].call(mime_type) unless mime_type == "text/plain"
end
```

## API

You can also use methods for inferring extension directly:

```rb
Shrine.infer_extension("image/jpeg")
# => ".jpeg"

Shrine.extension_inferrers[:mime_types].call("image/jpeg")
# => ".jpeg"
```

## Instrumentation

If the `instrumentation` plugin has been loaded, the `infer_extension` plugin
adds instrumentation around inferring extension.

```rb
# instrumentation plugin needs to be loaded *before* infer_extension
plugin :instrumentation
plugin :infer_extension
```

Inferring extension will trigger a `extension.shrine` event with the following
payload:

| Key          | Description                            |
| :--          | :----                                  |
| `:mime_type` | MIME type to infer extension from      |
| `:uploader`  | The uploader class that sent the event |

A default log subscriber is added as well which logs these events:

```
Extension (5ms) – {:mime_type=>"image/jpeg", :uploader=>Shrine}
```

You can also use your own log subscriber:

```rb
plugin :infer_extension, log_subscriber: -> (event) {
  Shrine.logger.info JSON.generate(name: event.name, duration: event.duration, **event.payload)
}
```
```
{"name":"extension","duration":5,"mime_type":"image/jpeg","uploader":"Shrine"}
```

Or disable logging altogether:

```rb
plugin :infer_extension, log_subscriber: nil
```

[infer_extension]: /lib/shrine/plugins/infer_extension.rb
[mime-types]: https://github.com/mime-types/ruby-mime-types
[mini_mime]: https://github.com/discourse/mini_mime
