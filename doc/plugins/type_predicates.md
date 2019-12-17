---
title: Type Predicates
---

The [`type_predicates`][type_predicates] plugin adds predicate methods to
`Shrine::UploadedFile` based on the MIME type. By default, it uses the
[MiniMime] gem for looking up MIME types.

```rb
# Gemfile
gem "mini_mime"
```
```rb
Shrine.plugin :type_predicates
```

## General predicates

The plugin adds four predicate methods based on the general type of the file:

```rb
file.image? # returns true for any "image/*" MIME type
file.video? # returns true for any "video/*" MIME type
file.audio? # returns true for any "audio/*" MIME type
file.text?  # returns true for any "text/*" MIME type
```

If `mime_type` metadata value is nil, `Shrine::Error` will be raised.

## Specific predicates

The `UploadedFile#type?` method takes a file extension, and returns whether the
`mime_type` metadata value of the uploaded file matches the MIME type
associated to the given file extension.

```rb
file.type?(:jpg) # returns true if MIME type is "image/jpeg"
file.type?(:svg) # returns true if MIME type is "image/svg+xml"
file.type?(:mov) # returns true if MIME type is "video/quicktime"
file.type?(:ppt) # returns true if MIME type is "application/vnd.ms-powerpoint"
...
```

For convenience, you can create predicate methods for specific file types:

```rb
Shrine.plugin :type_predicates, methods: %i[jpg svg mov ppt]
```
```rb
file.jpg? # returns true if MIME type is "image/jpeg"
file.svg? # returns true if MIME type is "image/svg+xml"
file.mov? # returns true if MIME type is "video/quicktime"
file.ppt? # returns true if MIME type is "application/vnd.ms-powerpoint"
```

If `mime_type` metadata value is nil, or the underlying MIME type library
doesn't recognize a given type, `Shrine::Error` will be raised.

### MIME database

The MIME type lookup by file extension is done by the underlying MIME type
library ([MiniMime] by default). You can change the MIME type library via the
`:mime` plugin option:

```rb
Shrine.plugin :type_predicates, mime: :marcel # requires adding "marcel" gem to the Gemfile
```

The following MIME type libraries are supported:

| Name          | Description                                                           |
| :----         | :---------                                                            |
| `:mini_mime`  | (**Default**.) Uses [MiniMime] gem to look up MIME type by extension. |
| `:mime_types` | Uses [mime-types] gem to look up MIME type by extension.              |
| `:mimemagic`  | Uses [MimeMagic] gem to look up MIME type by extension.               |
| `:marcel`     | Uses [Marcel] gem to look up MIME type by extension.                  |
| `:rack_mime`  | Uses [Rack::Mime] to look up MIME type by extension.                  |

You can also specify a custom block, which receives the extension and is
expected to return the corresponding MIME type. Inside the block you can call
into existing MIME type libraries:

```rb
Shrine.plugin :type_predicates, mime: -> (extension) do
  mime_type   = Shrine.type_lookup(extension, :marcel)
  mime_type ||= Shrine.type_lookup(extension, :mini_mime)
  mime_type
end
```

[type_predicates]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/type_predicates.rb
[MiniMime]: https://github.com/discourse/mini_mime
[mime-types]: https://github.com/mime-types/ruby-mime-types
[MimeMagic]: https://github.com/minad/mimemagic
[Marcel]: https://github.com/basecamp/marcel
[Rack::Mime]: https://github.com/rack/rack/blob/master/lib/rack/mime.rb
