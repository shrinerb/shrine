# Migrating to another storage

While your application is live in production and performing uploads, it may
happen that you decide you want to change your storage (the `:store`). Shrine
by design allows you to do that easily, with zero downtime, by deploying the
change in 2 phases.

## Phase 1: Changing the storage

The first stage, add the desired storage to your registry, and make it your
current store (let's say that you're migrating from FileSystem to S3):

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", subdirectory: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", subdirectory: "uploads/store"),
  new_store: Shrine::Storage::S3.new(**s3_options),
}

Shrine.plugin :default_storage, store: :new_store
```

This will make already uploaded files stay uploaded on `:store`, and all new
files will be uploaded to `:new_store`.

## Phase 2: Copying existing files

After you've deployed the previous change, it's time to copy all the existing
files to the new storage, and update the records. This is how you can do it
if you're using Sequel:

```rb
Shrine.plugin :migration_helpers

User.paged_each do |user|
  user.update_avatar do |avatar|
    user.avatar_store.upload(avatar)
  end
end

# Repeat for all other attachments and models
```

Now your uploaded files are successfully copied to the new storage, so you
should be able to safely delete the old one.

## Phase 3 and 4: Renaming new storage (optional)

The uploads will now be happening on the right storage, but if you would rather
rename `:new_store` back to `:store`, you can do two more phases. **First** you
need to deploy aliasing `:new_store` to `:store` (and make the default storage
be `:store` again):

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", subdirectory: "uploads/cache"),
  store: Shrine::Storage::S3.new(**s3_options),
}

Shrine.storages[:new_store] = Shrine.storages[:store]
```

**Second**, you should rename the storage names on existing records. With
Sequel it would be something like:

```rb
Shrine.plugin :migration_helpers

User.paged_each do |user|
  user.update_avatar do |avatar|
    avatar.to_json.gsub('new_store', 'store')
  end
end

# Repeat for all other attachments and models
```

Now everything should be in order and you should be able to remove the
`:new_store` alias.
