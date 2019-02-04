# Tempfile

The `tempfile` plugin makes it easier to reuse a single copy of an uploaded
file on disk.

```rb
Shrine.plugin :tempfile
```

The plugin provides the `UploadedFile#tempfile` method, which when called on an
open uploaded file will return a copy of its content on disk. The first time
the method is called the file content will cached into a temporary file and
returned. On any subsequent method calls the cached temporary file will be
returned directly. The temporary file is deleted when the uploaded file is
closed.

```rb
uploaded_file.open do
  # ...
  uploaded_file.tempfile #=> #<Tempfile:...> (file is cached)
  # ...
  uploaded_file.tempfile #=> #<Tempfile:...> (cache is returned)
  # ...
end # tempfile is deleted

# OR

uploaded_file.open
# ...
uploaded_file.tempfile #=> #<Tempfile:...> (file is cached)
# ...
uploaded_file.tempfile #=> #<Tempfile:...> (cache is returned)
# ...
uploaded_file.close # tempfile is deleted
```

This plugin also modifies `Shrine.with_file` to call `UploadedFile#tempfile`
when the given IO object is an open `UploadedFile`. Since `Shrine.with_file` is
typically called on the `Shrine` class directly, it's recommended to load this
plugin globally.
