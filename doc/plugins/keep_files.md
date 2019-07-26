# Keep Files

The [`keep_files`][keep_files] plugin prevents file deletion when the attacher
is about to destroy currently attached or previously attached file. This
functionality is useful when implementing soft deletes, versioning, or in
general any scenario where you need to track history.

```rb
plugin :keep_files
```

[keep_files]: /lib/shrine/plugins/keep_files.rb
