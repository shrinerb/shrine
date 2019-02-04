# keep_files

The `keep_files` plugin gives you the ability to prevent files from being
deleted. This functionality is useful when implementing soft deletes, or when
implementing some kind of [event store] where you need to track history.

The plugin accepts the following options:

| Option       | Description                                                                     |
| :------      | :----------                                                                     |
| `:destroyed` | If set to `true`, destroying the record won't delete the associated attachment. |
| `:replaced`  | If set to `true`, uploading a new attachment won't delete the old one.          |

For example, the following will keep destroyed and replaced files:

```rb
plugin :keep_files, destroyed: true, replaced: true
```

[event store]: http://docs.geteventstore.com/introduction/event-sourcing-basics/
