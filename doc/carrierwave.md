# Shrine for CarrierWave Users

This guide is aimed at helping CarrierWave users transition to Shrine. First it
explains some key differences in the design between the two libraries.
Afterwards it explains how you can transition an existing app that uses
CarrierWave to Shrine. It then finishes off with an extensive reference of
CarrierWave's interface and what is the equivalent in Shrine.

## Uploaders

Shrine has a concept of uploaders similar to CarrierWave's, which allows you to
have different uploading logic for different types of files:

```rb
class ImageUploader < Shrine
  # uploading logic
end
```

While in CarrierWave you choose a storages for uploaders directly, in Shrine
you first register storages globally (under a symbol name), and then you can
instantiate uploaders with a specific storage.

```rb
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
}
```
```rb
cache_uploader = Shrine.new(:cache)
store_uploader = Shrine.new(:store)
```

CarrierWave uses symbols for referencing storages (`:file`, `:fog`, ...), but
in Shrine storages are simple Ruby classes which you can instantiate directly.
This makes storages much more flexible, because this way they can have their
own options that are specific to them.

### Processing

In Shrine processing is done instance-level in the `#process` method, and can
be specified for each phase. You can return a single processed file or a hash of
versions (with the `versions` plugin):

```rb
require "image_processing/mini_magick" # part of the "image_processing" gem

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :versions, names: [:small, :medium, :large]

  def process(io, context)
    if context[:phase] == :store
      thumb = resize_to_limit(io.download, 300, 300)
      {original: io, thumb: thumb}
    end
  end
end
```

## Attachments

Like CarrierWave, Shrine also provides integrations with ORMs, it ships with
plugins for both Sequel and ActiveRecord (but it can also be used with simple
PORO models).

```rb
Shrine.plugin :sequel       # If you're using Sequel
Shrine.plugin :activerecord # If you're using ActiveRecord
```

Instead of giving you class methods for "mounting" uploaders, in Shrine you
generate attachment modules which you simply include in your models:

```rb
class User < Sequel::Model
  include ImageUploader[:avatar] # adds `avatar`, `avatar=` and `avatar_url` methods
end
```

You models are required to have the `<attachment>_data` column, in the above
case `avatar_data`. Shrine stores storage, location, and additional metadata of
the uploaded file to that column.

### Multiple uploads

Shrine doesn't have support for multiple uploads like CarrierWave does, instead
it expects that you will implement multiple uploads yourself using a separate
model. This is a good thing, because the implementation is specific to the ORM
you're using, and it's analogous to how you would implement adding items to any
dynamic one-to-many relationship. Take a look at the [example app] which
demonstrates how easy it is to implement multiple uploads.

## Migrating from CarrierWave

You have an existing app using CarrierWave and you want to transfer it to
Shrine. Let's assume we have a `Photo` model with the "image" attachment. First
we need to create the `image_data` column for Shrine:

```rb
add_column :photos, :image_data, :text
```

Afterwards we need to make new uploads write to the `image_data` column. This
can be done by including the below module to all models that have CarrierWave
attachments:

```rb
require "fastimage"

module CarrierwaveShrineSynchronization
  def self.included(model)
    model.before_save do
      self.class.uploaders.each_key do |name|
        write_shrine_data(name) if changes.key?(name)
      end
    end
  end

  def write_shrine_data(name)
    uploader = send(name)

    if read_attribute(name).present?
      data = uploader_to_shrine_data(uploader)

      if uploader.versions.any?
        data = {original: data}
        uploader.versions.each do |name, version|
          data[name] = uploader_to_shrine_data(version)
        end
      end

      write_attribute(:"#{name}_data", data.to_json)
    else
      write_attribute(:"#{name}_data", nil)
    end
  end

  private

  # If you'll be using `:prefix` on your Shrine storage, make sure to
  # subtract it from the path assigned as `:id`.
  def uploader_to_shrine_data(uploader)
    path = uploader.store_path(read_attribute(uploader.mounted_as))

    size   = uploader.file.size if changes.key?(uploader.mounted_as)
    size ||= FastImage.new(uploader.url).content_length
    size ||= File.size(File.join(uploader.root, path))
    filename = File.basename(path)
    mime_type = MIME::Types.type_for(path).first.to_s.presence

    {
      storage: :store,
      id: path,
      metadata: {
        size: size,
        filename: filename,
        mime_type: mime_type,
      },
    }
  end
end
```
```rb
class Photo < ActiveRecord::Base
  mount_uploader :image, ImageUploader
  include CarrierwaveShrineSynchronization # needs to be after `mount_uploader`
end
```

After you deploy this code, the `image_data` column should now be successfully
synchronized with new attachments.  Next step is to run a script which writes
all existing CarrierWave attachments to `image_data`:

```rb
Photo.find_each do |photo|
  Photo.uploaders.each_key { |name| photo.write_shrine_data(name) }
  photo.save!
end
```

Now you should be able to rewrite your application so that it uses Shrine
instead of CarrierWave, using equivalent Shrine storages. For help with
translating the code from CarrierWave to Shrine, you can consult the reference
below.

## CarrierWave to Shrine direct mapping

### `CarrierWave::Uploader::Base`

#### `.storage`

When using models, by default all storages use `:cache` for cache, and `:store`
for store. If you want to change that, you can use the `default_storage`
plugin:

```rb
Shrine.storages[:foo] = Shrine::Storage::Foo.new(*args)
```
```rb
class ImageUploader
  plugin :default_storage, store: :foo
end
```

#### `.process`, `.version`

As explained in the "Processing" section, processing is done by overriding the
`Shrine#process` method.

#### `.before`, `.after`

In Shrine you can get callbacks by loading the `hooks` plugin. Unlike
CarrierWave, and much like Sequel, Shrine implements callbacks by overriding
instance methods:

```rb
class ImageUploader < Shrine
  plugin :hooks

  def after_upload(io, context)
    super
    # do something
  end
end
```

#### `#store!`, `#cache!`

In Shrine you store and cache files by instantiating it with a corresponding
storage, and calling `#upload`:

```rb
ImageUploader.new(:cache).upload(file)
ImageUploader.new(:store).upload(file)
```

Note that in Shrine you cannot pass in a path to the file, you always have to
pass an IO-like object, which is required to respond to: `#read(*args)`,
`#size`, `#eof?`, `#rewind` and `#close`.

#### `#retrieve_from_store!` and `#retrieve_from_cache!`

In Shrine you simply call `#download` on the uploaded file:

```rb
uploaded_file = ImageUploader.new(:store).upload(file)
uploaded_file.download #=> #<Tempfile>
```

#### `#url`

In Shrine you call `#url` on uploaded files:

```rb
user.avatar #=> #<Shrine::UploadedFile>
user.avatar.url #=> "/uploads/398454ujedfggf.jpg"
```

#### `#identifier`

This method corresponds to `#original_filename` on the uploaded file:

```rb
user.avatar #=> #<Shrine::UploadedFile>
user.avatar.original_filename #=> "avatar.jpg"
```

#### `#store_dir`, `#cache_dir`

Shrine here provides a `#generate_location` method, which is triggered for all
storages:

```rb
class ImageUploader < Shrine
  def generate_location(io, context)
    "#{context[:record].class}/#{context[:record].id}/#{io.original_filename}"
  end
end
```

The `context` variable holds the additional data, like the attacment name and
the record instance. You might also want to use the `pretty_location` plugin
for automatically generating an organized folder structure.

#### `#default_url`

For default URLs you can use the `default_url` plugin:

```rb
class ImageUploader < Shrine
  plugin :default_url do |context|
    "/attachments/#{context[:name]}/default.jpg"
  end
end
```

The `context` variable holds the name of the attachment, record instance and
in some cases the `:version`.

#### `#extension_white_list`, `#extension_black_list`

In Shrine extension whitelisting/blacklisting is a part of validations, and is
provided by the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_extension_inclusion [/jpe?g/, 'png'] # whitelist
    validate_extension_exclusion ['php']          # blacklist
  end
end
```

#### `#blacklist_mime_type_pattern`, `#whitelist_mime_type_pattern`

In Shrine MIME type whitelisting/blacklisting is part of validations, and is
provided by the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type_inclusion [/image/] # whitelist
    validate_mime_type_exclusion [/video/] # blacklist
  end
end
```

#### `#size_range`

In Shrine file size validations are typically done using the
`validation_helpers` plugin:


```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_min_size 0
    validate_max_size 5*1024*1024 # 5 MB
  end
end
```

#### `#recreate_versions!`

Shrine doesn't have a built-in way of regenerating versions, because that's
very individual and depends on what versions you want regenerated, what ORM are
you using, how many records there are in your database etc. The [Regenerating
versions] guide provides some useful tips on this task.

### Models

The only thing that Shrine requires from your models is a `<attachment>_data`
column (e.g. if your attachment is "avatar", you need the `avatar_data` column).

#### `.mount_uploader`

In Shrine you make include attachment modules directly:

```rb
Shrine.plugin :sequel
```
```rb
class User < Sequel::Model
  include ImageUploader[:avatar]
end
```

#### `#<attachment>=`

The attachment module adds an attachment setter:

```rb
user.avatar = File.open("avatar.jpg")
```

Note that unlike CarrierWave, you cannot pass in file paths, the input needs to
be an IO-like object.

#### `#<attachment>`

CarrierWave returns the uploader, but Shrine returns a `Shrine::UploadedFile`,
a representation of the file uploaded to the storage:

```rb
user.avatar #=> #<Shrine::UploadedFile>
user.avatar.methods #=> [:url, :download, :read, :exists?, :delete, ...]
```

If attachment is missing, nil is returned.

#### `#<attachment>_url`

This method is simply a shorthand for "if attachment is present, call `#url`
on it, otherwise return nil":

```rb
user.avatar_url #=> nil
user.avatar = File.open("avatar.jpg")
user.avatar_url #=> "/uploads/ksdf934rt.jpg"
```

The `versions` plugin extends this method to also accept a version name as the
argument (`user.avatar_url(:thumb)`).

#### `#<attachment>_cache`

Shrine doesn't provide this method, instead it expects to recieve the
attachment through the accessor, you can assign it `<attachment>_data`:

```erb
<%= form_for @user do |f| %>
  <%= f.hidden_field :avatar, value: @user.avatar_data %>
  <%= f.file_field :avatar %>
<% end %>
```

You might also want to look at the `cached_attachment_data` plugin.

#### `#remote_<attachment>_url`

In Shrine this method is provided by the `remote_url` plugin.

#### `#remove_<attachment>`

In Shrine this method is provided by the `remove_attachment` plugin.

### Configuration

This section walks through various configuration options in CarrierWave, and
shows what are Shrine's equivalents.

#### `root`, `base_path`, `permissions`, `directory_permissions`

In Shrine these are configured on the FileSystem storage directly.

#### `storage`, `storage_engines`

As mentioned before, in Shrine you register storages through `Shrine.storages`,
and the attachment storages will automatically be `:cache` and `:store`, but
you can change this with the `default_storage` plugin.

#### `fog_*`

These options are set on the [shrine-fog] storage.

#### `delete_tmp_file_after_storage`, `remove_previously_stored_file_after_update`

By default Shrine deletes cached and replaced files, but you can choose to keep
those files by loading the `keep_files` plugin:

```rb
Shrine.plugin :keep_files, cached: true, replaced: true
```

#### `move_to_cache`, `move_to_store`

Shrine brings this functionality through the `moving` plugin.

```rb
Shrine.plugin :moving, storages: [:cache]
```

#### `validate_integrity`, `ignore_integrity_errors`

Shrine does this with validation, which are best done with the
`validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    # Evaluated inside an instance of Shrine::Attacher.
    if record.guest?
      validate_max_size 2*1024*1024, message: "is too large (max is 2 MB)"
      validate_mime_type_inclusion ["image/jpg", "image/png", "image/gif"]
    end
  end
end
```

#### `validate_download`, `ignore_download_errors`

Shrine's `remote_url` plugin always rescues download errors and transforms
them to validation errors.

#### `validate_processing`, `ignore_processing_errors`

Shrine doesn't offer any built-in ways of rescuing processing errors, because
it completely depends on how you do your processing. You can easily add your
own rescuing:

```rb
class ImageUploader < Shrine
  def process(io, context)
    # processing
  rescue SomeProcessingError
    # handling
  end
end
```

#### `enable_processing`

You can just do conditionals inside if `Shrine#process`.

#### `ensure_multipart_form`

No equivalent, it depends on your application whether you need the form to be
multipart or not.

[image_processing]: https://github.com/janko-m/image_processing
[example app]: https://github.com/janko-m/shrine-example
[Regenerating versions]: http://shrinerb.com/rdoc/files/doc/regenerating_versions_md.html
[shrine-fog]: https://github.com/janko-m/shrine-fog
