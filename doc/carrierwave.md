---
title: Shrine for CarrierWave Users
---

This guide is aimed at helping CarrierWave users transition to Shrine, and it
consists of three parts:

1. Explanation of the key differences in design between CarrierWave and Shrine
2. Instructions how to migrate and existing app that uses CarrierWave to Shrine
3. Extensive reference of CarrierWave's interface with Shrine equivalents

## Overview

### Uploader

Shrine shares CarrierWave's concept of **uploaders**, classes which encapsulate
file attachment logic for different file types:

```rb
class ImageUploader < Shrine
  # attachment logic
end
```

However, while CarrierWave uploaders are responsible for most of the
attachment logic (uploading to temporary/permanent storage, retrieving the
uploaded file, file validation, processing versions), Shrine distributes
these responsibilities across several core classes:

| Class                  | Description                                                        |
| :----                  | :-----------                                                       |
| `Shrine`               | handles uploads, metadata extraction, location generation          |
| `Shrine::UploadedFile` | exposes metadata, implements downloading, URL generation, deletion |
| `Shrine::Attacher`     | handles caching & storing, dirty tracking, persistence, versions   |

Shrine uploaders themselves are functional: they receive a file on the input
and return the uploaded file on the output. There are no state changes.

```rb
uploader      = ImageUploader.new(:store)
uploaded_file = uploader.upload(file, :store)
uploaded_file          #=> #<Shrine::UploadedFile>
uploaded_file.url      #=> "https://my-bucket.s3.amazonaws.com/store/kfds0lg9rer.jpg"
uploaded_file.download #=> #<File:/tmp/path/to/file>
```

### Storage

In CarrierWave, you configure storage in global configuration:

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

In Shrine, the configuration options are passed directly to the storage class:

```rb
Shrine.storages[:store] = Shrine::Storage::S3.new(
  bucket:            "my-bucket",
  access_key_id:     "abc",
  secret_access_key: "xyz",
  region:            "eu-west-1",
)
```

#### Temporary storage

Where CarrierWave's temporary storage is hardcoded to disk, Shrine can use any
storage for temporary storage. So, if you have multiple servers or want to do
[direct uploads], you can use AWS S3 as temporary storage:

```rb
Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(**s3_options),
}
```

### Persistence

While CarrierWave persists only the filename of the original uploaded file,
Shrine persists storage and metadata information as well:

```rb
{
  "id": "path/to/image.jpg",
  "storage": "store",
  "metadata": {
    "filename": "nature.jpg",
    "size": 4739472,
    "mime_type": "image/jpeg"
  }
}
```

This way we have all information about uploaded files, without having to
retrieve the file from the storage.

```rb
photo.image.id          #=> "path/to/image.jpg"
photo.image.storage_key #=> :store
photo.image.metadata    #=> { "filename" => "...", "size" => ..., "mime_type" => "..." }

photo.image.original_filename #=> "nature.jpg"
photo.image.size              #=> 4739472
photo.image.mime_type         #=> "image/jpeg"
```

#### Location

CarrierWave persists only the filename of the uploaded file, and recalculates
the full location dynamically based on location configuration. This can be
dangerous, because if some component of the location happens to change, all
existing links might become invalid.

To avoid this, Shrine persists the full location on attachment, and uses it
when generating file URL. So, even if you change how file locations are
generated, existing files that are on old locations will still remain
accessible.

### Processing

CarrierWave uses a class-level DSL for generating versions, which internally
uses uploader subclassing and does in-place processing.

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

In contrast, in Shrine you perform processing on the instance level as a
functional transformation, which is a lot simpler and more flexible:

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

#### Retrieving versions

When retrieving versions, CarrierWave returns a list of declared versions which
may or may not have been generated. In contrast, Shrine persists data of
uploaded processed files into the database (including any extracted metadata),
which then becomes the source of truth on which versions have been generated.

```rb
photo.image              #=> #<Shrine::UploadedFile id="original.jpg" ...>
photo.image_derivatives  #=> {}

photo.image_derivatives! # triggers processing
photo.image_derivatives  #=>
# {
#   large:  #<Shrine::UploadedFile id="large.jpg"  metadata={"size"=>873232, ...} ...>,
#   medium: #<Shrine::UploadedFile id="medium.jpg" metadata={"size"=>94823,  ...} ...>,
#   small:  #<Shrine::UploadedFile id="small.jpg"  metadata={"size"=>37322,  ...} ...>,
# }
```

#### Reprocessing versions

Shrine doesn't have a built-in way of regenerating versions, because that has
to be written and optimized differently depending on what versions have changed
which persistence library you're using, how many records there are in the table
etc.

However, there is an extensive guide for [Managing Derivatives], which provides
instructions on how to make these changes safely and with zero downtime.

### Validation

File validation in Shrine is also instance-level, which allows using
conditionals:

```rb
class ImageUploader < CarrierWave::Uploader::Base
  def extension_whitelist
    %w[jpg jpeg png webp]
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
    validate_max_size 10*1024*1024
    validate_extension %w[jpg jpeg png webp]

    if validate_mime_type %w[image/jpeg image/png image/webp]
      validate_max_dimensions [5000, 5000]
    end
  end
end
```

#### Custom metadata

With Shrine you can also extract and validate any custom metadata:

```rb
class VideoUploader < Shrine
  plugin :add_metadata
  plugin :validation

  add_metadata :duration do |io|
    FFMPEG::Movie.new(io.path).duration
  end

  Attacher.validate do
    if file.duration > 5*60*60
      errors << "must not be longer than 5 hours"
    end
  end
end
```

### Multiple uploads

Shrine doesn't have support for multiple uploads out-of-the-box like
CarrierWave does. Instead, you can implement them using a separate table with a
one-to-many relationship to which the files will be attached. The [Multiple
Files] guide explains this setup in more detail.

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

You can use [`Shrine::Storage::S3`][S3] (built-in),
[`Shrine::Storage::GoogleCloudStorage`][shrine-gcs], or generic
[`Shrine::Storage::Fog`][shrine-fog] storage. The reference will assume you're
using S3 storage.

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

[Managing Derivatives]: https://shrinerb.com/docs/changing-derivatives
[direct uploads]: https://shrinerb.com/docs/getting-started#direct-uploads
[S3]: https://shrinerb.com/docs/storage/s3
[shrine-gcs]: https://github.com/renchap/shrine-google_cloud_storage
[shrine-fog]: https://github.com/shrinerb/shrine-fog
[Multiple Files]: https://shrinerb.com/docs/multiple-files
