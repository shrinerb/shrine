# Shrine for Refile Users

This guide is aimed at helping Refile users transition to Shrine, and it consists
of three parts:

1. Explanation of the key differences in design between Refile and Shrine
2. Instructions how to migrate and existing app that uses Refile to Shrine
3. Extensive reference of Refile's interface with Shrine equivalents

## Uploaders

Shrine borrows many great concepts from Refile: Refile's "backends" are here
named "storages", it uses the same IO abstraction for uploading and representing
uploaded files, similar attachment logic, and direct uploads are also supported.

While in Refile you work with storages directly, Shrine uses *uploaders* which
wrap storage uploads:

```rb
storage = Shrine.storages[:store]
storage #=> #<Shrine::Storage::S3>

uploaded_file = Shrine.upload(image, :store)
uploaded_file #=> #<Shrine::UploadedFile ...>
uploaded_file.storage #=> #<Shrine::Storage::S3>
```

This way Shrine can perform tasks like generating location, extracting
metadata, processing, and logging, which are all storage-agnostic, and leave
storages to deal only with actual file storage. And these tasks can be
configured differently depending on the types of files you're uploading:

```rb
class ImageUploader < Shrine
  add_metadata :exif do |io|
    MiniMagick::Image.new(io).exif
  end
end
```
```rb
class VideoUploader < Shrine
  add_metadata :duration do |io|
    FFMPEG::Movie.new(io.path).duration
  end
end
```

### Processing

Shrine provides on-the-fly processing via the
[`derivation_endpoint`][derivation_endpoint] plugin:

```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount ImageUploader.derivation_endpoint => "/derivations/image"
end
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivation_endpoint,
    secret_key: "<YOUR SECRET KEY>",
    prefix:     "derivations/image" # needs to match the mount point in routes

  derivation :thumbnail do |file, width, height|
    ImageProcessing::MiniMagick
      .source(file)
      .resize_to_limit!(width.to_i, height.to_i)
  end
end
```

Shrine also support processing up front using the [`derivatives`][derivatives]
plugin.

### URL

While Refile serves all files through the Rack endpoint mounted in your app,
Shrine serves files directly from storage services:

```rb
Refile.attachment_url(@photo, :image) #=> "/attachments/cache/50dfl833lfs0gfh.jpg"
```

```rb
@photo.image.url #=> "https://my-bucket.s3.amazonaws.com/cache/50dfl833lfs0gfh.jpg"
```

If you're using storage which don't expose files over URL (e.g. a database
storage), or you want to secure your downloads, you can also serve files
through your app using the [`download_endpoint`][download_endpoint] plugin.

## Attachments

While in Refile you configure attachments by passing options to `.attachment`,
in Shrine you define all your uploading logic inside uploaders, and then
generate an attachment module with that uploader which is included into the
model:

```rb
class Photo < Sequel::Model
  extend Shrine::Sequel::Attachment
  attachment :image, destroy: false
end
```

```rb
class ImageUploader < Shrine
  plugin :sequel
end

class Photo < Sequel::Model
  include ImageUploader::Attachment(:image)
end
```

This way we can encapsulate all attachment logic inside a class and share it
between different models.

### Metadata

Refile allows you to save additional metadata about uploaded files in additional
columns, so you can define `<attachment>_filename`, `<attachment>_content_type`,
or `<attachment>_size`.

Shrine, on the other hand, saves all metadata into a single `<attachment>_data`
column:

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

By default "filename", "size" and "mime_type" is stored, but you can also store
image dimensions, or define any other custom metadata. This also allow storages
to add their own metadata.

### Validations

In Refile you define validations by passing options to `.attachment`, while
in Shrine you define validations on the instance-level, which allows them to
be dynamic:

```rb
class Photo < Sequel::Model
  attachment :image,
    extension: %w[jpg jpeg png gif],
    content_type: %w[image/jpeg image/png image/gif]
end
```

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_extension %w[jpg jpeg png gif]
    validate_mime_type %w[image/jpeg image/png image/gif]
    validate_max_size 10*1024*1024
  end
end
```

Refile extracts the MIME type from the file extension, which means it can
easily be spoofed (just give a PHP file a `.jpg` extension). Shrine has the
`determine_mime_type` plugin for determining MIME type from file *content*.

### Multiple uploads

Shrine doesn't have a built-in solution for accepting multiple uploads, but
it's actually very easy to do manually, see the [demo app] on how you can do
multiple uploads directly to S3.

## Direct uploads

Shrine borrows Refile's idea of direct uploads, and ships with
`upload_endpoint` and `presign_endpoint` plugins which provide endpoints for
uploading files and generating presigns.

```rb
Shrine.plugin :upload_endpoint
Shrine.upload_endpoint(:cache) # Rack app that uploads files to specified storage

Shrine.plugin :upload_endpoint
Shrine.presign_endpoint(:cache) # Rack app that generates presigns for specified storage
```

Unlike Refile, Shrine doesn't ship with complete JavaScript which you can just
include to make it work. However, [Uppy] is an excellent JavaScript file upload
library that integrates wonderfully with Shrine, see the [demo app] for a
complete example.

## Migrating from Refile

You have an existing app using Refile and you want to transfer it to
Shrine. Let's assume we have a `Photo` model with the "image" attachment. First
we need to create the `image_data` column for Shrine:

```rb
add_column :photos, :image_data, :text
```

Afterwards we need to make new uploads write to the `image_data` column. This
can be done by including the below module to all models that have Refile
attachments:

```rb
require "shrine"

Shrine.storages = {
  cache: ...,
  store: ...,
}

Shrine.plugin :model
```
```rb
module RefileShrineSynchronization
  def write_shrine_data(name)
    attacher = Shrine::Attacher.from_model(self, name)

    if read_attribute("#{name}_id").present?
      attacher.set shrine_file(name)
    else
      attacher.set nil
    end
  end

  def shrine_file(name)
    Shrine.uploaded_file(
      storage:  :store,
      id:       send("#{name}_id"),
      metadata: {
        "size"      => (send("#{name}_size") if respond_to?("#{name}_size")),
        "filename"  => (send("#{name}_filename") if respond_to?("#{name}_filename")),
        "mime_type" => (send("#{name}_content_type") if respond_to?("#{name}_content_type")),
      }
    )
  end
end
```
```rb
class Photo < ActiveRecord::Base
  attachment :image
  include RefileShrineSynchronization

  before_save do
    write_shrine_data(:image) if changes.key?(:image_id)
  end
end
```

After you deploy this code, the `image_data` column should now be successfully
synchronized with new attachments.  Next step is to run a script which writes
all existing Refile attachments to `image_data`:

```rb
Photo.find_each do |photo|
  photo.write_shrine_data(:image)
  photo.save!
end
```

Now you should be able to rewrite your application so that it uses Shrine
instead of Refile, using equivalent Shrine storages. For help with translating
the code from Refile to Shrine, you can consult the reference below.

## Refile to Shrine direct mapping

### `Refile`

#### `.cache`, `.store`, `.backends`

Shrine calles these "storages", and it doesn't have special accessors for
`:cache` and `:store`:

```rb
Shrine.storages = {
  cache: Shrine::Storage::Foo.new(*args),
  store: Shrine::Storage::Bar.new(*args),
}
```

#### `.app`, `.mount_point`, `.automount`

The `upload_endpoint`, `presign_endpoint`, and `derivation_endpoint` plugins
provide methods for generating Rack apps, but you need to mount them
explicitly:

```rb
# config/routes.rb
Rails.application.routes.draw do
  # adds `POST /images/upload` endpoint
  mount ImageUploader.upload_endpoint(:cache) => "/images/upload"
end
```

#### `.allow_uploads_to`

The `Shrine.upload_endpoint` and `Shrine.presign_endpoint` require you to
specify the storage that will be used.

#### `.logger`

```rb
Shrine.logger
```

#### `.processors`, `.processor`

```rb
class ImageUploader < Shrine
  plugin :derivatives

  derivation :thumbnail do |file, width, height|
    # ...
  end
end
```

#### `.types`

In Shrine, validations are done by calling `.validate` on the attacher class:

```rb
class MyUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 5*1024*1024
  end
end
```

#### `.extract_filename`, `.extract_content_type`

In Shrine equivalents are (private) methods `Shrine#extract_filename` and
`Shrine#extract_mime_type`.

#### `.app_url`

You should use your framework to generate the URL to your mounted direct
endpoint.

#### `.attachment_url`, `.file_url`

You can call `#url` on the uploaded file, or `#<name>_url` on the model.
Additionally you can use the `download_endpoint` plugin.

#### `.upload_url`, `.attachment_upload_url`, `.presign_url`, `.attachment_presign_url`

These should be generated directly by you, it depends on where you've mounted
the direct endpoint.

#### `.host`, `.cdn_host`, `.app_host`, `.allow_downloads_from`, `allow_origin`, `.content_max_age`

Not needed since Shrine doesn't offer on-the-fly processing.

#### `.secret_key`, `.token`, `.valid_token?`

Not needed since Shrine doesn't offer on-the-fly processing.

### `attachment`

Shrine's equivalent to calling the attachment is including an attachment module
of an uploader:

```rb
class Photo
  include ImageUploader::Attachment(:image)
end
```

#### `:extension`, `:content_type`, `:type`

In Shrine validations are done instance-level inside the uploader, most
commonly with the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_extension %w[jpg jpeg png]
    validate_mime_type %w[image/jpeg image/png]
  end
end
```

#### `:cache`, `:store`

Shrine provides a `default_storage` plugin for setting custom storages on the
uploader:

```rb
Shrine.storages[:custom_cache] = Shrine::Storage::Foo.new(*args)
Shrine.storages[:custom_store] = Shrine::Storage::Bar.new(*args)
```
```rb
class ImageUploader < Shrine
  plugin :default_storage, cache: :custom_cache, store: :custom_store
end
```

#### `:raise_errors`

No equivalent currently exists in Shrine.

### `accepts_attachments_for`

No equivalent in Shrine, but take a look at the "[Multiple Files]" guide.

### Form helpers

#### `attachment_field`

The following Refile code

```rb
form_for @user do |form|
  form.attachment_field :profile_image
end
```

is equivalent to the following Shrine code

```rb
Shrine.plugin :cached_attachment_data
```
```rb
form_for @user do |form|
  form.hidden_field :profile_image, value: @user.cached_profile_image_data
  form.file_field :profile_image
end
```

### Model methods

#### `remove_<attachment>`

Shrine comes with a `remove_attachment` plugin which adds the same
`#remove_<attachment>` method to the model.

```rb
Shrine.plugin :remove_attachment
```
```rb
form_for @user do |form|
  form.hidden_field :profile_image, value: @user.cached_profile_image_data
  form.file_field :profile_image
  form.check_box :remove_profile_image
end
```

#### `remote_<attachment>_url`

Shrine comes with a `remote_url` plugin which adds the same
`#<attachment>_remote_url` method to the model.

```rb
Shrine.plugin :remote_url
```
```rb
form_for @user do |form|
  form.hidden_field :profile_image, value: @user.cached_profile_image_data
  form.file_field :profile_image
  form.text_field :profile_image_remote_url
end
```

[image_processing]: https://github.com/janko/image_processing
[Uppy]: https://uppy.io
[Direct Uploads to S3]: /doc/direct_s3.md#readme
[demo app]: https://github.com/shrinerb/shrine/tree/master/demo
[Multiple Files]: /doc/multiple_files.md#readme
[derivation_endpoint]: /doc/plugins/derivation_endpoint.md#readme
[download_endpoint]: /doc/plugins/download_endpoint.md#readme
[derivatives]: /doc/plugins/derivatives.md#readme
