---
title: Delete Raw
---

The [`delete_raw`][delete_raw] plugin will automatically delete raw files that
have been uploaded. This is especially useful when doing processing, to ensure
that temporary files have been deleted after upload.

```rb
plugin :delete_raw
```

By default any raw file that was uploaded will be deleted, but you can limit
this only to files uploaded to certain storages:

```rb
plugin :delete_raw, storages: [:store]
```

If you want to skip deletion for a certain upload, you can pass `delete: false`
to the uploader:

```rb
uploader.upload(file, delete: false)
```

[delete_raw]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/delete_raw.rb
