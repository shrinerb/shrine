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
    region:                "eu-west-1",
  }
  config.fog_directory = "my-bucket"
end
```
```rb
Shrine.storages[:store] = Shrine::Storage::S3.new(
  bucket:            "my-bucket",
  access_key_id:     "abc",
  secret_access_key: "xyz",
  region:            "eu-west-1",
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
  store: Shrine::Storage::S3.new(**s3_options),
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
uploaded_file = ImageUploader.upload(file, :store)
uploaded_file          #=> #<Shrine::UploadedFile>
uploaded_file.url      #=> "https://my-bucket.s3.amazonaws.com/store/kfds0lg9rer.jpg"
uploaded_file.download #=> #<File:/tmp/path/to/file>
```

## Processing

In contrast to CarrierWave's class-level DSL, in Shrine processing is defined
and performed on the instance-level.

```rb
class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  version :large do
    process resize_to_limit: [800, 800]
  end

  version :medium do
    process resize_to_limit: [500, 500]
  end

  version :small do
    process resize_to_limit: [300, 300]
  end
end
```

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivatives

  Attacher.derivatives_processor do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    {
      large:  magick.resize_to_limit!(800, 800),
      medium: magick.resize_to_limit!(500, 500),
      small:  magick.resize_to_limit!(300, 300),
    }
  end
end
```

CarrierWave performs processing before validations, which is a huge security
issue, as it allows users to give arbitrary files to your processing tool, even
if you have validations. With Shrine you can perform processing after
validations.

Shrine doesn't have a built-in way of regenerating versions, but there is an
extensive [Managing Derivatives] guide.

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
    validate_extension %w[jpg jpeg gif png]
    validate_mime_type %w[image/jpeg image/gif image/png]
    validate_max_size 10*1024*1024
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
  include ImageUploader::Attachment(:image)
end
```

### Attachment column

You models are required to have the `<attachment>_data` column, which Shrine
uses to save storage, location, and metadata of the uploaded file.

```rb
photo.image_data #=>
# {
#   "storage": "store",
#   "id": "photo/1/image/0d9o8dk42.png",
#   "metadata": {
#     "filename":  "nature.png",
#     "size":      49349138,
#     "mime_type": "image/png"
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
photo.image               #=> #<Shrine::UploadedFile>
photo.image.width         #=> 800

photo.image(:thumb)       #=> #<Shrine::UploadedFile>
photo.image(:thumb).width #=> 300
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
require "shrine"

Shrine.storages = {
  cache: ...,
  store: ...,
}

Shrine.plugin :model
Shrine.plugin :derivatives
```
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
    attacher = Shrine::Attacher.form_model(self, name)

    if read_attribute(name).present?
      attacher.set shrine_file(uploader)

      uploader.versions.each do |name, version|
        attacher.merge_derivatives(name => shrine_file(version))
      end
    else
      attacher.set nil
    end
  end

  private

  # If you'll be using `:prefix` on your Shrine storage, make sure to
  # subtract it from the path assigned as `:id`.
  def shrine_file(uploader)
    name     = uploader.mounted_as
    filename = read_attribute(name)
    path     = uploader.store_path(filename)

    Shrine.uploaded_file(
      storage:  :store,
      id:       path,
      metadata: { "filename" => filename },
    )
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
  photo.image_attacher.refresh_metadata!
  photo.save
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

Processing is defined by using the `derivatives` plugin:

```rb
class ImageUploader < Shrine
  plugin :derivatives

  Attacher.derivatives_processor do |original|
    magick = ImageProcessing::MiniMagick.source(image)

    {
      large:  magick.resize_to_limit!(800, 800),
      medium: magick.resize_to_limit!(500, 500),
      small:  magick.resize_to_limit!(300, 300),
    }
  end
end
```

#### `.before`, `.after`

There is no Shrine equivalent for CarrierWave's callbacks.

#### `#store!`, `#cache!`

In Shrine you store and cache files by passing the corresponding storage to
`Shrine.upload`:

```rb
ImageUploader.upload(file, :cache)
ImageUploader.upload(file, :store)
```

Note that in Shrine you cannot pass in a path to the file, you always have to
pass an IO-like object, which is required to respond to: `#read(*args)`,
`#size`, `#eof?`, `#rewind` and `#close`.

#### `#retrieve_from_store!` and `#retrieve_from_cache!`

In Shrine you simply call `#download` on the uploaded file:

```rb
uploaded_file = ImageUploader.upload(file, :store)
uploaded_file.download #=> #<Tempfile:/path/to/file>
```

#### `#url`

In Shrine you call `#url` on uploaded files:

```rb
photo.image     #=> #<Shrine::UploadedFile>
photo.image.url #=> "/uploads/398454ujedfggf.jpg"
photo.image_url #=> "/uploads/398454ujedfggf.jpg" (shorthand)
```

#### `#identifier`

This method corresponds to `#original_filename` on the uploaded file:

```rb
photo.image                   #=> #<Shrine::UploadedFile>
photo.image.original_filename #=> "avatar.jpg"
```

#### `#store_dir`, `#cache_dir`

Shrine here provides a `#generate_location` method, which is triggered for all
storages:

```rb
class ImageUploader < Shrine
  def generate_location(io, record: nil, **)
    "#{record.class}/#{record.id}/#{io.original_filename}"
  end
end
```

You might also want to use the `pretty_location` plugin for automatically
generating an organized folder structure.

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

#### `#extension_white_list`, `#extension_black_list`

In Shrine, extension whitelisting/blacklisting is a part of validations, and is
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

In Shrine, MIME type whitelisting/blacklisting is part of validations, and is
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
    validate_size 0..5*1024*1024 # 5 MB
  end
end
```

#### `#recreate_versions!`

Shrine doesn't have a built-in way of regenerating versions, because that's
very individual and depends on what versions you want regenerated, what ORM are
you using, how many records there are in your database etc. The [Managing
Derivatives] guide provides some useful tips on this task.

### Models

The only thing that Shrine requires from your models is a `<attachment>_data`
column (e.g. if your attachment is "image", you need the `image_data` column).

#### `.mount_uploader`

In Shrine you make include attachment modules directly:

```rb
Shrine.plugin :sequel
```
```rb
class User < Sequel::Model
  include ImageUploader::Attachment(:avatar)
end
```

#### `#<attachment>=`

The attachment module adds an attachment setter:

```rb
photo.image = File.open("avatar.jpg", "rb")
```

Note that unlike CarrierWave, you cannot pass in file paths, the input needs to
be an IO-like object.

#### `#<attachment>`

CarrierWave returns the uploader, but Shrine returns a `Shrine::UploadedFile`,
a representation of the file uploaded to the storage:

```rb
photo.image #=> #<Shrine::UploadedFile>
photo.image.methods #=> [:url, :download, :read, :exists?, :delete, ...]
```

If attachment is missing, nil is returned.

#### `#<attachment>_url`

This method is simply a shorthand for "if attachment is present, call `#url`
on it, otherwise return nil":

```rb
photo.image_url #=> nil
photo.image = File.open("avatar.jpg", "rb")
photo.image_url #=> "/uploads/ksdf934rt.jpg"
```

The `derivatives` plugin extends this method to also accept a version name as
the argument (`photo.image_url(:thumb)`).

#### `#<attachment>_cache`

Shrine has the `cached_attachment_data` plugin, which gives model a reader method
that you can use for retaining the cached file:

```rb
Shrine.plugin :cached_attachment_data
```
```rb
form_for @photo do |f|
  f.hidden_field :image, value: @photo.cached_image_data
  f.file_field :image
end
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
Shrine.plugin :keep_files
```

#### `move_to_cache`, `move_to_store`

You can tell the `FileSystem` storage that it should move files by specifying
the `:move` upload option:

```rb
Shrine.plugin :upload_options, cache: { move: true }, store: { move: true }
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
      validate_max_size 2*1024*1024, message: "must not be larger than 2 MB"
      validate_mime_type %w[image/jpg image/png image/webp]
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
Shrine::Storage::S3.new(upload_options: { content_disposition: "attachment" }, **options)
```

#### `:fog_public`

The object permissions can be configured with the `:acl` upload option:

```rb
Shrine::Storage::S3.new(upload_options: { acl: "private" }, **options)
```

#### `:fog_authenticated_url_expiration`

The `#url` method accepts the `:expires_in` option, you can set the default
expiration with the `url_options` plugin:

```rb
plugin :url_options, store: { expires_in: 600 }
```

#### `:fog_use_ssl_for_aws`, `:fog_aws_accelerate`

Shrine allows you to override the S3 endpoint:

```rb
Shrine::Storage::S3.new(use_accelerate_endpoint: true, **options)
```

[image_processing]: https://github.com/janko/image_processing
[demo app]: https://github.com/shrinerb/shrine/tree/master/demo
[Managing Derivatives]: /doc/changing_derivatives.md#readme
[shrine-fog]: https://github.com/shrinerb/shrine-fog
[direct uploads]: /doc/direct_s3.md#readme
[`Shrine::Storage::S3`]: /doc/storage/s3.md#readme
[`Shrine::Storage::GoogleCloudStorage`]: https://github.com/renchap/shrine-google_cloud_storage
[`Shrine::Storage::Fog`]: https://github.com/shrinerb/shrine-fog
