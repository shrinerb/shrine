# Parsed JSON

The [`parsed_json`][parsed_json] plugin is suitable for the case when your
framework is automatically parsing JSON query parameters, allowing you to
assign cached files with hashes/arrays.

```rb
plugin :parsed_json
```

```rb
photo.image = {
  "id"       => "sdf90s2443.jpg",
  "storage"  => "cache",
  "metadata" => {
    "filename"  => "nature.jpg",
    "size"      => 29475,
    "mime_type" => "image/jpeg",
  }
}
```

[parsed_json]: /lib/shrine/plugins/parsed_json.rb
