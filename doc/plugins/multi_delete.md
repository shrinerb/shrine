# Multi Delete

The `multi_delete` plugins allows you to leverage your storage's multi delete
capabilities.

```rb
plugin :multi_delete
```

This plugin allows you pass an array of files to `Shrine#delete`.

```rb
uploader.delete([file1, file2, file3])
```

Now if you're using Storage::S3, deleting an array of files will issue a single
HTTP request. Some other storages may support multi deletes as well. The
`versions` plugin uses this plugin for deleting multiple versions at once.
