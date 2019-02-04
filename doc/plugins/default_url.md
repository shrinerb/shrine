# Default URL

The `default_url` plugin allows setting the URL which will be returned when the
attachment is missing.

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
