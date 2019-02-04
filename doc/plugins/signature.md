# Signature

The `signature` plugin provides the ability to calculate a hash from file
content. This hash can be used as a checksum or just as a unique signature for
the uploaded file.

```rb
Shrine.plugin :signature
```

The plugin adds a `#calculate_signature` instance and class method to the
uploader. The method accepts an IO object and a hashing algorithm, and returns
the calculated hash.

```rb
Shrine.calculate_signature(io, :md5)
#=> "9a0364b9e99bb480dd25e1f0284c8555"
```

You can then use the `add_metadata` plugin to add a new metadata field with the
calculated hash.

```rb
plugin :add_metadata

add_metadata :md5 do |io, context|
  calculate_signature(io, :md5)
end
```

This will generate a hash for each uploaded file, but if you want to generate
one only for the original file, you can add a conditional:

```rb
add_metadata :md5 do |io, context|
  calculate_signature(io, :md5) if context[:action] == :cache
end
```

The following hashing algorithms are supported: SHA1, SHA256, SHA384, SHA512,
MD5, and CRC32.

You can also choose which format will the calculated hash be encoded in:

```rb
Shrine.calculate_signature(io, :sha256, format: :base64)
```

The supported encoding formats are `hex` (default), `base64`, and `none`.
