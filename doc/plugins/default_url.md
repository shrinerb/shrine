# Default URL

The [`default_url`][default_url] plugin allows setting the URL which will be
returned when the attachment is missing.

```rb
plugin :default_url

Attacher.default_url do |options|
  "/#{name}/missing.jpg"
end
```

`Attacher#url` returns the default URL when attachment is missing. Any passed
in URL options will be present in the `options` hash.

```rb
attacher.url #=> "/avatar/missing.jpg"
# or
user.avatar_url #=> "/avatar/missing.jpg"
```

The default URL block is evaluated in the context of an instance of
`Shrine::Attacher`.

```rb
Attacher.default_url do |options|
  self #=> #<Shrine::Attacher>

  name   #=> :avatar
  record #=> #<User>
end
```

## Host

If the default URL is relative, the URL host can be specified via the `:host`
option:

```rb
plugin :default_url, host: "https://example.com"
```
```rb
user.avatar_url #=> "https://example.com/avatar/missing.jpg"
```

[default_url]: /lib/shrine/plugins/default_url.rb
