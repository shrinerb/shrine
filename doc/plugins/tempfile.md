---
title: Tempfile
---

The [`tempfile`][tempfile] plugin makes it easier to reuse a single copy of an
uploaded file on disk.

```rb
Shrine.plugin :tempfile
```

The plugin provides the `UploadedFile#tempfile` method, which returns a copy
of the uploaded file's content on disk. The first time the method is called
the file content will be downloaded into a temporary file and returned. On
any subsequent method calls the cached temporary file will be returned
directly. If the uploaded file is currently open, its tempfile is deleted
when the uploaded file is closed; otherwise it's deleted whenever it becomes
unreachable and is garbage collected (so it's still recommended to close the
uploaded file when you're done with it, to have the tempfile cleaned up
deterministically).

```rb
uploaded_file.tempfile #=> #<Tempfile:...> (file is downloaded and cached)
uploaded_file.tempfile #=> #<Tempfile:...> (cache is returned)

# OR

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

[tempfile]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/tempfile.rb
