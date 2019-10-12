---
title: Signature
---

The [`signature`][signature] plugin provides the ability to calculate a hash
from file content. This hash can be used as a checksum or just as a unique
signature for the uploaded file.

```rb
Shrine.plugin :signature
```

## API

The plugin adds a `#calculate_signature` instance and class method to the
uploader. The method accepts an IO object and a hashing algorithm, and returns
the calculated hash.

```rb
Shrine.calculate_signature(io, :md5) #=> "9a0364b9e99bb480dd25e1f0284c8555"
# or just
Shrine.signature(io, :md5) #=> "9a0364b9e99bb480dd25e1f0284c8555"
```

The following hashing algorithms are supported: SHA1, SHA256, SHA384, SHA512,
MD5, and CRC32.

You can also choose which format will the calculated hash be encoded in:

```rb
Shrine.calculate_signature(io, :sha256, format: :base64)
```

The supported encoding formats are `hex` (default), `base64`, and `none`.

## Adding metadata

You can then use the `add_metadata` plugin to add a new metadata field with the
calculated hash.

```rb
plugin :add_metadata

add_metadata :md5 do |io|
  calculate_signature(io, :md5)
end
```

This will generate a hash for each uploaded file, but if you want to generate
one only for the original file, you can add a conditional:

```rb
add_metadata :md5 do |io, action: nil, **|
  calculate_signature(io, :md5) if action == :cache
end
```

## Instrumentation

If the `instrumentation` plugin has been loaded, the `signature` plugin adds
instrumentation around signature calculation.

```rb
# instrumentation plugin needs to be loaded *before* signature
plugin :instrumentation
plugin :signature
```

Calculating signature will trigger a `signature.shrine` event with the
following payload:

| Key         | Description                            |
| :--         | :----                                  |
| `:io`       | The IO object                          |
| `:uploader` | The uploader class that sent the event |

A default log subscriber is added as well which logs these events:

```plaintext
MIME Type (33ms) – {:io=>StringIO, :uploader=>Shrine}
```

You can also use your own log subscriber:

```rb
plugin :signature, log_subscriber: -> (event) {
  Shrine.logger.info JSON.generate(name: event.name, duration: event.duration, **event.payload)
}
```
```plaintext
{"name":"signature","duration":24,"io":"#<StringIO:0x00007fb7c5b08b80>","uploader":"Shrine"}
```

Or disable logging altogether:

```rb
plugin :signature, log_subscriber: nil
```

[signature]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/signature.rb
