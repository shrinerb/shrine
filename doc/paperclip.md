# Shrine for Paperclip Users

This guide is aimed at helping Paperclip users transition to Shrine. We will
first generally mention what are the key differences. Afterwards there is a
complete reference of Paperclip's interface and what is the equivalent in
Shrine.

## Uploaders

While in Paperclip you write your uploading logic as a list of options inside
your models, in Shrine you instead have "uploader" classes where you put all
your uploading logic.

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type_inclusion [/^image/]
  end

  def process(io, context)
    # processing
  end
end
```

Unlike Paperclip, in Shrine you can use these uploaders directly if you have
to do some lower-level logic. First you need to register storages, and then
you can instantiate uploaders with a specific storage:

```rb
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
}
```
```rb
uploader = Shrine.new(:cache)
uploaded_file = uploader.upload(File.open("nature.jpg"))
uploaded_file.path #=> "/uploads/cache/s9ffdkfd02kd.jpg"
uploaded_file.original_filename #=> "nature.jpg"
```

### Processing

In Shrine you do processing inside the uploader's `#process` method, and unlike
Paperclip, the processing is done on instance-level, so you have maximum
flexibility. In Shrine you generate versions by simply returning a hash, and
also loading the `versions` plugin to make your uploader recognize versions:

```rb
require "image_processing/mini_magick" # part of the "image_processing" gem

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :versions, names: [:original, :thumb]

  def process(io, context)
    if context[:phase] == :store
      thumb = resize_to_limit(io.download, 300, 300)
      {original: io, thumb: thumb}
    end
  end
end
```

#### Regenerating versions

Shrine doesn't have a built-in way of regenerating versions, because that's
very individual and depends on what versions you want regenerated, what ORM are
you using, how many records there are in your database etc. The [Regenerating
versions] guide provides some useful tips on this task.

### Logging

In Paperclip you enable logging by setting `Paperclip.options[:log] = true`.
Shrine also provides logging with the `logging` plugin:

```rb
Shrine.plugin :logging
```

## Attachments

The uploaders can then integrate with models by generating attachment modules
which are included into the models. Shrine ships with plugins for Sequel and
ActiveRecord ORMs, so you first have to load the one for your ORM:

```rb
Shrine.plugin :sequel       # If you're using Sequel
Shrine.plugin :activerecord # If you're using ActiveRecord
```

Now you use your uploaders to generate "attachment modules", which you can then
include in your models:

```rb
class User < Sequel::Model
  include ImageUploader[:avatar] # adds `avatar`, `avatar=` and `avatar_url` methods
end
```

Unlike in Paperclip which requires you to have `<attachment>_file_name`,
`<attachment>_file_size`, `<attachment>_content_type` and
`<attachment>_updated_at` columns, in Shrine you only need to have an
`<attachment>_data` text column, and all information will be stored there.

The attachments use `:store` for storing the files, and `:cache` for caching.
The latter is something Paperclip doesn't do, but caching before storing is
really great because the file then persists on validation errors, and also in
backgrounding you can show the users the cached version before the file is
finished storing.

### Validations

In Shrine validations are done inside uploader classes, and validation methods
are provided by the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 5*1024*1024
    validate_mime_type_inclusion [/^image/]
  end
end
```

For presence validation you should use the one provided by your ORM:

```rb
class User < Sequel::Model
  include ImageUploader[:avatar]

  def validate
    validates_presence [:avatar]
  end
end
```

#### MIME type spoofing

By default Shrine will extract the MIME type from the `Content-Type` header of
the uploaded file, which is solely determined from the file extension, so it's
prone to spoofing. Shrine provides the `determine_mime_type` plugin which
determines the MIME type from the file *contents* instead:

```rb
Shrine.plugin :determine_mime_type
```

By default the UNIX [file] utility is used, but you can choose other analyzers.
Unlike Paperclip, you won't get any errors if the MIME type is "spoofed",
instead it's better if you simply validate allowed MIME types.

### Hooks/Callbacks

Shrine's `hooks` plugin provides callbacks for Shrine, so to get Paperclip's
`(before|after)_post_process`, you can override `#before_process` and
`#after_process` methods:

```rb
class ImageUploader < Shrine
  plugin :hooks

  def before_process(io, context)
    # ...
    super
  end

  def after_process(io, context)
    super
    # ...
  end
end
```

## Paperclip to Shrine direct mapping

### `has_attached_file`

As mentioned above, Shrine's equivalent of `has_attached_file` is including
an attachment module:

```rb
class User < Sequel::Model
  include ImageUploader[:avatar] # adds `avatar`, `avatar=` and `avatar_url` methods
end
```

Now we'll list all options that `has_attached_file` accepts, and explain
Shrine's equivalents:

#### `:storage`

In Shrine attachments will automatically use `:cache` and `:store` storages
which you have to register:

```rb
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
}
```

You can change that for a specific uploader with the `default_storage` plugin.

#### `:styles`, `:processors`, `:convert_options`

As explained in the "Processing" section, processing is done by overriding the
`Shrine#process` method.

#### `:default_url`

For default URLs you can use the `default_url` plugin:

```rb
class ImageUploader < Shrine
  plugin :default_url do |context|
    "/attachments/#{context[:name]}/default.jpg"
  end
end
```

#### `:preserve_files`

Shrine provides a `keep_files` plugin which allows you to keep files that would
otherwise be deleted:

```rb
Shrine.plugin :keep_files, destroyed: true
```

#### `:path`, `:url`, `:interpolator`, `:url_generator`

Shrine by default stores your files in the same directory, but you can also
load the `pretty_location` plugin for nice folder structure:

```rb
Shrine.plugin :pretty_location
```

Alternatively, if you want to generate locations yourself you can override the
`#generate_location` method:

```rb
class ImageUploader < Shrine
  def generate_location(io, context)
    # ...
  end
end
```

#### `:validate_media_type`

Shrine has this functionality in the `determine_mime_type` plugin.

### `Paperclip::Attachment`

This section explains the equivalent of Paperclip attachment's methods, in
Shrine this is an instance of `Shrine::UploadedFile`.

#### `#url`, `#styles`

If you're generating versions in Shrine, the attachment will be a hash of
uploaded files:

```rb
user.avatar.class #=> Hash
user.avatar #=>
# {
#   small:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   large:  #<Shrine::UploadedFile>,
# }

user.avatar[:small].url #=> "..."
# or
user.avatar_url(:small) #=> "..."
```

#### `#path`

Shrine doesn't have this because storages are abstract and this would be
specific to the filesystem, but the closest is probably `#id`:

```rb
user.avatar.id #=> "users/342/avatar/398543qjfdsf.jpg"
```

#### `#reprocess!`

Shrine doesn't have an equivalent to this, but the [Regenerating versions]
guide provides some useful tips on how to do this.

[file]: http://linux.die.net/man/1/file
[Regenerating versions]: http://shrinerb.com/rdoc/files/doc/regenerating_versions_md.html
