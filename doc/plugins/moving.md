# Moving

The [`moving`][moving] plugin will *move* files to storages instead of copying
them, when the storage supports it. For FileSystem this will issue a `mv`
command, which is instantaneous regardless of the filesize, so in that case
loading this plugin can significantly speed up the attachment process.

```rb
plugin :moving
```

By default files will be moved whenever the storage supports it. If you want
moving to happen only for certain storages, you can set `:storages`:

```rb
plugin :moving, storages: [:cache]
```

[moving]: /lib/shrine/plugins/moving.rb
