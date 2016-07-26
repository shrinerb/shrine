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

Unlike Paperclip, in Shrine you define and perform processing on
instance-level, which gives a lot of flexibility. As the result you can return
a single file or a hash of versions:

```rb
require "image_processing/mini_magick" # part of the "image_processing" gem

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :processing
  plugin :versions

  process(:store) do |io, context|
    thumbnail = resize_to_limit(io.download, 300, 300)
    {original: io, thumbnail: thumbnail}
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

Unlike in Paperclip which requires you to have 4 `<attachment>_*` columns, in
Shrine you only need to have an `<attachment>_data` text column, and all
information will be stored there (in the above case `avatar_data`).

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

## Migrating from Paperclip

You have an existing app using Paperclip and you want to transfer it to Shrine.
First we need to make new uploads write to the `<attachment>_data` column.
Let's assume we have a `Photo` model with the "image" attachment:

```rb
add_column :photos, :image_data, :text
```

Afterwards we need to make new uploads write to the `image_data` column. This
can be done by including the below module to all models that have Paperclip
attachments:

```rb
require "fastimage"

module PaperclipShrineSynchronization
  def self.included(model)
    model.before_save do
      Paperclip::AttachmentRegistry.each_definition do |klass, name, options|
        write_shrine_data(name) if changes.key?(:"#{name}_file_name") && klass == self.class
      end
    end
  end

  def write_shrine_data(name)
    attachment = send(name)

    if attachment.size.present?
      data = attachment_to_shrine_data(attachment)

      if attachment.styles.any?
        data = {original: data}
        attachment.styles.each do |name, style|
          data[name] = style_to_shrine_data(style)
        end
      end

      write_attribute(:"#{name}_data", data.to_json)
    else
      write_attribute(:"#{name}_data", nil)
    end
  end

  private

  # If you'll be using a `:prefix` on your Shrine storage, or you're storing
  # files on the filesystem, make sure to subtract the appropriate part
  # from the path assigned to `:id`.
  def attachment_to_shrine_data(attachment)
    {
      storage: :store,
      id: attachment.path,
      metadata: {
        size: attachment.size,
        filename: attachment.original_filename,
        content_type: attachment.content_type,
      },
    }
  end

  # If you'll be using a `:prefix` on your Shrine storage, or you're storing
  # files on the filesystem, make sure to subtract the appropriate part
  # from the path assigned to `:id`.
  def style_to_shrine_data(style)
    attachment = style.attachment
    path = attachment.path(style.name)
    url = attachment.url(style.name)
    file = attachment.instance_variable_get("@queued_for_write")[style.name]

    size   = file.size if file
    size ||= FastImage.new(url).content_length
    size ||= File.size(path)
    filename = File.basename(path)
    mime_type = MIME::Types.type_for(path).first.to_s.presence

    {
      storage: :store,
      id: path,
      metadata: {
        size: size,
        filename: filename,
        mime_type: mime_type,
      }
    }
  end
end
```
```rb
class Photo < ActiveRecord::Base
  has_attached_file :image
  include PaperclipShrineSynchronization # needs to be after `has_attached_file`
end
```

After you deploy this code, the `image_data` column should now be successfully
synchronized with new attachments.  Next step is to run a script which writes
all existing CarrierWave attachments to `image_data`:

```rb
Photo.find_each do |photo|
  Paperclip::AttachmentRegistry.each_definition do |klass, name, options|
    photo.write_shrine_data(name) if klass == Photo
  end
  photo.save!
end
```

Now you should be able to rewrite your application so that it uses Shrine
instead of Paperclip, using equivalent Shrine storages. For help with
translating the code from Paperclip to Shrine, you can consult the reference
below.

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
