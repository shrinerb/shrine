# Backup

The [`backup`][backup] plugin allows you to automatically back up stored files
to an additional storage.

```rb
storages[:backup_store] = Shrine::Storage::S3.new(options)
plugin :backup, storage: :backup_store
```

After a file is stored, it will be reuploaded from store to the provided backup
storage.

```rb
user.update(avatar: file) # uploaded both to :store and :backup_store
```

By default whenever stored files are deleted backed up files are deleted as
well, but you can keep files on the "backup" storage by passing `delete:
false`:

```rb
plugin :backup, storage: :backup_store, delete: false
```

Note that when adding this plugin with already existing stored files, Shrine
won't know whether a stored file is backed up or not, so attempting to delete
the backup could result in an error. To avoid that you can set `delete: false`
until you manually back up the existing stored files.

[backup]: /lib/shrine/plugins/backup.rb
