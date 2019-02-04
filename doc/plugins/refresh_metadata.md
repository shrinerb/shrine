# Refresh Metadata

The `refresh_metadata` plugin allows you to re-extract metadata from an
uploaded file.

```rb
plugin :refresh_metadata
```

It provides `UploadedFile#refresh_metadata!` method, which triggers metadata
extraction (calls `Shrine#extract_metadata`) with the uploaded file opened for
reading, and updates the existing metadata hash with the results.

```rb
uploaded_file.refresh_metadata!
uploaded_file.metadata # re-extracted metadata
```

For remote storages this will make an HTTP request to open the file for
reading, but only the portion of the file needed for extracting each metadata
value will be downloaded.

If the uploaded file is already open, it is passed to metadata extraction as
is.

```rb
uploaded_file.open do
  uploaded_file.refresh_metadata!
  # ...
end
```
