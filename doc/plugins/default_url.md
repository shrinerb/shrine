---
title: Default URL
---

The [`default_url`][default_url] plugin allows setting the URL which will be
returned when there is no attached file.

```rb
plugin :default_url

Attacher.default_url do |options|
  "/#{name}/missing.jpg"
end
```

The `Attacher#url` method will return the default URL when attachment is
missing:

```rb
user.avatar_url #=> "/avatar/missing.jpg"
# or
attacher.url #=> "/avatar/missing.jpg"
```

Any URL options passed will be available in the default URL block:

```rb
attacher.url(foo: "bar")
```
```rb
Attacher.default_url do |options|
  options #=> { foo: "bar" }
end
```

The default URL block is evaluated in the context of an instance of
`Shrine::Attacher`.

```rb
Attacher.default_url do |options|
  self    #=> #<Shrine::Attacher>

  file    #=> #<Shrine::UploadedFile>
  name    #=> :avatar
  record  #=> #<User>
  context #=> { ... }

  # ...
end
```

## Host

If the default URL is relative, the URL host can be specified via the `:host`
option:

```rb
plugin :default_url, host: "https://example.com"
```
```rb
attacher.url #=> "https://example.com/avatar/missing.jpg"
```

[default_url]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/default_url.rb
