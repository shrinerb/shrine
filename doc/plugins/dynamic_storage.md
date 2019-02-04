# Dynamic Storage

The `dynamic_storage` plugin allows you to register a storage using a regex,
and evaluate the storage class dynamically depending on the regex.

Example:

```rb
plugin :dynamic_storage

storage /store_(\w+)/ do |match|
  Shrine::Storages::S3.new(bucket: match[1])
end
```

The above example uses S3 storage where the bucket name depends on the storage
name suffix. For example, `:store_foo` will use S3 storage which saves files to
the bucket "foo". The block is yielded an instance of `MatchData`.

This can be useful in combination with the `default_storage` plugin.
