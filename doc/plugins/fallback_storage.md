---
title: Fallback Storage
---

The [`fallback_storage`][fallback_storage] plugin allows you to specify a secondary (fallback) storage that
Shrine will read from if a file is not found in the primary storage.

This is especially useful when setting up a staging or development environment where you want to read files
from production storage without replicating or copying large amounts of data locally.

```rb
Shrine.storages = {
  cache:    Shrine::Storage::S3.new(endpoint: "https://stage.example.com", prefix: "cache"),
  store:    Shrine::Storage::S3.new(endpoint: "https://stage.example.com"),
  fallback: Shrine::Storage::S3.new(endpoint: "https://production.example.com"),
}

Shrine.plugin :fallback_storage
```

By default, the plugin looks for a storage named `:fallback`. You can override the fallback storage
name by passing the `:store` option:

```rb
Shrine.plugin :fallback_storage, store: :production_store
```

## How It Works

The plugin intercepts file existence checks, URL generation, and file reading methods on
`Shrine::UploadedFile`.

When performing read or check operations, Shrine will first attempt to query the main storage.
If the file is missing in the primary storage, it seamlessly falls back to the configured fallback storage:

* `UploadedFile#exists?` — Returns true if the file exists in the primary storage OR in the fallback storage.
* `UploadedFile#url` — Returns the URL from the primary storage if the file exists there,
otherwise generates the URL using the fallback storage.
* `UploadedFile#open` (and methods relying on it like `read`, `download`, etc.) — Opens the file from the
primary storage if present, otherwise opens it from the fallback storage.

## Write and Delete Operations

The plugin only affects read operations. Uploads, replacements, and deletions interact strictly with
the primary storage:

* Uploads: `Shrine.upload` writes files only to the main storage.
* Deletes: `UploadedFile#delete` removes the file only from the primary storage. The fallback storage remains
untouched.

```ruby
# File exists only in fallback storage
file = Shrine.uploaded_file({ "id" => "some-id", "storage" => "store" })
file.exists? # => true (found in fallback)

# Deleting removes it from primary storage, but fallback remains intact
file.delete
file.exists? # => true (still found in fallback)
```

For additional security and reliability when pointing to a production environment, it is recommended
to configure the credentials for the fallback storage (e.g., S3 access keys) with read-only permissions.

## Rails example

A common use case is a staging environment that should have access to production files without storing
its own copies. You can configure Shrine differently per environment:

```rb
# config/initializers/shrine.rb
if Rails.env.production?
  Shrine.storages = {
    cache: Shrine::Storage::S3.new(endpoint: "https://production.example.com", prefix: "cache"),
    store: Shrine::Storage::S3.new(endpoint: "https://production.example.com"),
  }
else
  Shrine.storages = {
    cache: Shrine::Storage::S3.new(endpoint: "https://stage.example.com", prefix: "cache"),
    store: Shrine::Storage::S3.new(endpoint: "https://stage.example.com"),
    production: Shrine::Storage::S3.new(endpoint: "https://production.example.com"),
  }

  Shrine.plugin :fallback_storage, store: :production
end
```

With this setup, staging uploads go to the staging endpoint, but any read for a missing file
will automatically look in the production endpoint.

[fallback_storage]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/fallback_storage.rb
