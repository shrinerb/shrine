# Shrine for CarrierWave Users

This guide is aimed at helping CarrierWave users transition to Shrine, and it
consists of three parts:

1. Explanation of the key differences in design between CarrierWave and Shrine
2. Instructions how to migrate and existing app that uses CarrierWave to Shrine
3. Extensive reference of CarrierWave's interface with Shrine equivalents

## Storage

While in CarrierWave you configure storage in global configuration, in Shrine
storage is a class which you can pass options to during initialization:

```rb
CarrierWave.configure do |config|
  config.fog_provider = "fog/aws"
  config.fog_credentials = {
    provider:              "AWS",
    aws_access_key_id:     "abc",
    aws_secret_access_key: "xyz",
  }
  config.fog_directory = "my-bucket"
end
```
```rb
Shrine.storages[:store] = Shrine::Storage::S3.new(
  bucket:                "my-bucket",
  aws_access_key_id:     "abc",
  aws_secret_access_key: "xyz",
)
```

In CarrierWave temporary storage cannot be configured; it saves and retrieves
files from the filesystem, you can only set the directory. With Shrine both
temporary (`:cache`) and permanent (`:store`) storage are first-class citizens
and fully configurable, so you can also have files *cached* on S3 (preferrably
via [direct uploads]):

```rb
Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(prefix: "store", **s3_options),
}
```

## Uploader

Shrine shares CarrierWave's concept of *uploaders*, classes which encapsulate
file attachment logic for different file types:

```rb
class ImageUploader < Shrine
  # attachment logic
end
```

However, uploaders in CarrierWave are very broad; in addition to uploading and
deleting files, they also represent the uploaded file. Shrine has a separate
`Shrine::UploadedFile` class which represents the uploaded file.

```rb
uploader = ImageUploader.new(:store)
uploaded_file = uploader.upload(image)
uploaded_file          #=> #<Shrine::UploadedFile>
uploaded_file.url      #=> "https://my-bucket.s3.amazonaws.com/store/kfds0lg9rer.jpg"
uploaded_file.download #=> #<Tempfile>
```

### Processing

In contrast to CarrierWave's class-level DSL, in Shrine processing is defined
and performed on the instance-level. The result of processing can be a single
file or a hash of versions:

```rb
class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  process resize_to_limit: [800, 800]

  version :medium do
    process resize_to_limit: [500, 500]
  end

  version :small, from_version: :medium do
    process resize_to_limit: [300, 300]
  end
end
```

```rb
class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :processing
  plugin :versions

  process(:store) do |io, context|
    size_800 = resize_to_limit!(io.download, 800, 800)
    size_500 = resize_to_limit(size_800,     500, 500)
    size_300 = resize_to_limit(size_500,     300, 300)

    { original: size_800, medium: size_500, small: size_300 }
  end
end
```

This allows you to fully optimize processing, because you can easily specify
which files are processed from which, and even add parallelization.

CarrierWave performs processing before validations, which is a huge security
issue, as it allows users to give arbitrary files to your processing tool, even
if you have validations. Shrine performs processing after validations.

#### Reprocessing versions

Shrine doesn't have a built-in way of regenerating versions, because that has
to be written and optimized differently depending on whether you're adding or
removing a version, what ORM are you using, how many records there are in the
database etc. The [Reprocessing versions] guide provides some useful tips on
this task.

### Validations

Like with processing, validations in Shrine are also defined and performed on
instance-level:

```rb
class ImageUploader < CarrierWave::Uploader::Base
  def extension_whitelist
    %w[jpg jpeg gif png]
  end

  def content_type_whitelist
    /image\//
  end

  def size_range
    0..(10*1024*1024)
  end
end
```

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_extension_inclusion %w[jpg jpeg gif png]
    validate_mime_type_inclusion %w[image/jpeg image/gif image/png]
    validate_max_size 10*1024*1024 unless record.admin?
  end
end
```

## Attachments

Like CarrierWave, Shrine also provides integrations with ORMs. It ships with
plugins for both Sequel and ActiveRecord, but can also be used with just PORO
models.

```rb
Shrine.plugin :sequel       # if you're using Sequel
Shrine.plugin :activerecord # if you're using ActiveRecord
```

Instead of giving you class methods for "mounting" uploaders, in Shrine you
generate attachment modules which you simply include in your models, which
gives your models similar set of methods that CarrierWave gives:

```rb
class Photo < ActiveRecord::Base
  extend CarrierWave::ActiveRecord # done automatically by CarrierWave
  mount_uploader :image, ImageUploader
end
```
```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment.new(:avatar)
end
```

### Attachment column

You models are required to have the `<attachment>_data` column, which Shrine
uses to save storage, location, and metadata of the uploaded file.

```rb
photo.image_data #=>
# {
#   "storage" => "store",
#   "id" => "photo/1/image/0d9o8dk42.png",
#   "metadata" => {
#     "filename"  => "nature.png",
#     "size"      => 49349138,
#     "mime_type" => "image/png"
#   }
# }

photo.image.original_filename #=> "nature.png"
photo.image.size              #=> 49349138
photo.image.mime_type         #=> "image/png"
```

This is much more powerful than storing only the filename like CarrierWave
does, as it allows you to also store any additional metadata that you might
want to extract.

Unlike CarrierWave, Shrine will store this information for each processed
version, making them first-class citizens:

```rb
photo.image[:original]       #=> #<Shrine::UploadedFile>
photo.image[:original].width #=> 800

photo.image[:thumb]          #=> #<Shrine::UploadedFile>
photo.image[:thumb].width    #=> 300
```

Also, since CarrierWave stores only the filename, it has to recalculate the
full location each time it wants to generate the URL. That makes it really
difficult to move files to a new location, because changing how the location is
generated will now cause incorrect URLs to be generated for all existing files.
Shrine calculates the whole location only once and saves it to the column.

### Multiple uploads

Shrine doesn't have support for multiple uploads like CarrierWave does, instead
it expects that you will attach each file to a separate database record. This
is a good thing, because the implementation is specific to the ORM you're
using, and it's analogous to how you would implement any nested one-to-many
associations. Take a look at the [demo app] which shows how easy it is to
implement multiple uploads.

## Migrating from CarrierWave

You have an existing app using CarrierWave and you want to transfer it to
Shrine. Let's assume we have a `Photo` model with the "image" attachment. First
we need to create the `image_data` column for Shrine:

```rb
add_column :photos, :image_data, :text # or :json or :jsonb if supported
```

Afterwards we need to make new uploads write to the `image_data` column. This
can be done by including the below module to all models that have CarrierWave
attachments:

```rb
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

      # Remove the `.to_json` if you're using a JSON column, otherwise the JSON
      # object will be saved as an escaped string.
      write_attribute(:"#{name}_data", data.to_json)
    else
      write_attribute(:"#{name}_data", nil)
    end
  end

  private

  # If you'll be using `:prefix` on your Shrine storage, make sure to
  # subtract it from the path assigned as `:id`.
  def uploader_to_shrine_data(uploader)
    filename = read_attribute(uploader.mounted_as)
    path     = uploader.store_path(filename)

    {
      storage: :store,
      id: path,
      metadata: { filename: filename }
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

You'll notice that Shrine metadata will be absent from the migrated files'
data. You can run a script that will fill in any missing metadata defined in
your Shrine uploader:

```rb
Shrine.plugin :refresh_metadata

Photo.find_each do |photo|
  attachment = ImageUploader.uploaded_file(photo.image, &:refresh_metadata!)
  photo.update(image_data: attachment.to_json)
end
```

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
  plugin :default_url

  Attacher.default_url do |options|
    "/attachments/#{name}/default.jpg"
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
    validate_extension_inclusion %w[jpg jpeg png] # whitelist
    validate_extension_exclusion %w[php]          # blacklist
  end
end
```

#### `#blacklist_mime_type_pattern`, `#whitelist_mime_type_pattern`, `#content_type_whitelist`, `#content_type_blacklist`

In Shrine MIME type whitelisting/blacklisting is part of validations, and is
provided by the `validation_helpers` plugin, though it doesn't support regexes:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type_inclusion %w[image/jpeg image/png] # whitelist
    validate_mime_type_exclusion %w[text/x-php]           # blacklist
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
  include ImageUploader::Attachment.new(:avatar)
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

Shrine has the `cached_attachment_data` plugin, which gives model a reader method
that you can use for retaining the cached file:

```rb
Shrine.plugin :cached_attachment_data
```
```erb
<%= form_for @user do |f| %>
  <%= f.hidden_field :avatar, value: @user.cached_avatar_data %>
  <%= f.file_field :avatar %>
<% end %>
```

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
      validate_mime_type_inclusion %w[image/jpg image/png image/gif]
    end
  end
end
```

#### `validate_download`, `ignore_download_errors`

Shrine's `remote_url` plugin always rescues download errors and transforms
them to validation errors.

#### `validate_processing`, `ignore_processing_errors`

In Shrine processing is performed *after* validations, and typically
asynchronously in a background job, so it is expected that you validate files
before processing.

#### `enable_processing`

You can just add conditionals in processing code.

#### `ensure_multipart_form`

No equivalent, it depends on your application whether you need the form to be
multipart or not.

### `CarrierWave::Storage::Fog`

You can use [`Shrine::Storage::S3`] \(built-in\),
[`Shrine::Storage::GoogleCloudStorage`], or generic [`Shrine::Storage::Fog`]
storage. The reference will assume you're using S3 storage.

#### `:fog_credentials`, `:fog_directory`

The S3 Shrine storage accepts `:access_key_id`, `:secret_access_key`, `:region`,
and `:bucket` options in the initializer:

```rb
Shrine::Storage::S3.new(
  access_key_id:     "...",
  secret_access_key: "...",
  region:            "...",
  bucket:            "...",
)
```

#### `:fog_attributes`

The object data can be configured via the `:upload_options` hash:

```rb
Shrine::Storage::S3.new(upload_options: {content_disposition: "attachment"}, **options)
```

#### `:fog_public`

The object permissions can be configured with the `:acl` upload option:

```rb
Shrine::Storage::S3.new(upload_options: {acl: "private"}, **options)
```

#### `:fog_authenticated_url_expiration`

The `#url` method accepts the `:expires_in` option, you can set the default
expiration with the `default_url_options` plugin:

```rb
plugin :default_url_options, store: {expires_in: 600}
```

#### `:fog_use_ssl_for_aws`, `:fog_aws_accelerate`

Shrine allows you to override the S3 endpoint:

```rb
Shrine::Storage::S3.new(endpoint: "https://s3-accelerate.amazonaws.com", **options)
```

[image_processing]: https://github.com/janko-m/image_processing
[demo app]: https://github.com/shrinerb/shrine/tree/master/demo
[Reprocessing versions]: http://shrinerb.com/rdoc/files/doc/regenerating_versions_md.html
[shrine-fog]: https://github.com/shrinerb/shrine-fog
[direct uploads]: http://shrinerb.com/rdoc/files/doc/direct_s3_md.html
[`Shrine::Storage::S3`]: http://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html
[`Shrine::Storage::GoogleCloudStorage`]: https://github.com/renchap/shrine-google_cloud_storage
[`Shrine::Storage::Fog`]: https://github.com/shrinerb/shrine-fog
