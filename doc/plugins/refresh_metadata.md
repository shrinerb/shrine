---
title: Refresh Metadata
---

The [`refresh_metadata`][refresh_metadata] plugin allows you to re-extract
metadata from an uploaded file.

```rb
plugin :refresh_metadata
```

It provides `#refresh_metadata!` method, which triggers metadata extraction
(calls `Shrine#extract_metadata`) with the uploaded file opened for reading,
and updates the existing metadata hash with the results. This can be done
on the attacher or the uploaded file level.

## Attacher

Calling `#refresh_metadata!` on a `Shrine::Attacher` object will re-extract
metadata of the attached file. When used with a [model], it will write new file
data back into the attachment attribute.

```rb
attacher.refresh_metadata!
attacher.file.metadata # re-extracted metadata
```

The `Attacher#context` hash will be forwarded to metadata extraction, as well
as any options that you pass in.

```rb
# via context
attacher.context[:foo] = "bar"
attacher.refresh_metadata! # passes `{ foo: "bar" }` options to metadata extraction

# via arguments
attacher.refresh_metadata!(foo: "bar") # passes `{ foo: "bar" }` options to metadata extraction
```

## Uploaded File

The `#refresh_metadata!` method can be called on a `Shrine::UploadedFile` object
as well.

```rb
uploaded_file.refresh_metadata!
uploaded_file.metadata # re-extracted metadata
```

If the uploaded file is not open, it is opened before and closed after metadata
extraction. For remote storage services this will make an HTTP request.
However, only the portion of the file needed for extracting metadata will be
downloaded.

If the uploaded file is already open, it is passed to metadata extraction as
is.

```rb
uploaded_file.open do
  uploaded_file.refresh_metadata! # uses the already opened file
  # ...
end
```

Any options passed in will be forwarded to metadata extraction:

```rb
uploaded_file.refresh_metadata!(foo: "bar") # passes `{ foo: "bar" }` options to metadata extraction
```

[refresh_metadata]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/refresh_metadata.rb
[model]: https://shrinerb.com/docs/plugins/model
