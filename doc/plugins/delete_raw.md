# Delete Raw

The `delete_raw` plugin will automatically delete raw files that have been
uploaded. This is especially useful when doing processing, to ensure that
temporary files have been deleted after upload.

```rb
plugin :delete_raw
```

By default any raw file that was uploaded will be deleted, but you can limit
this only to files uploaded to certain storages:

```rb
plugin :delete_raw, storages: [:store]
```
