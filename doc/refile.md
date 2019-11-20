---
title: Upgrading from Refile
---

This guide is aimed at helping Refile users transition to Shrine, and it consists
of three parts:

1. Explanation of the key differences in design between Refile and Shrine
2. Instructions how to migrate an existing app that uses Refile to Shrine
3. Extensive reference of Refile's interface with Shrine equivalents

## Overview

Shrine borrows many great concepts from Refile: Refile's "backends" are here
named "storages", it uses the same IO abstraction for uploading and
representing uploaded files, similar attachment logic, and direct uploads are
supported as well.

### Uploader

While in Refile you work with storages directly, Shrine uses *uploaders* which
wrap storage uploads:

```rb
storage = Shrine.storages[:store]
storage #=> #<Shrine::Storage::S3>

uploaded_file = Shrine.upload(image, :store)
uploaded_file #=> #<Shrine::UploadedFile ...>
uploaded_file.storage #=> #<Shrine::Storage::S3>
```

This way, Shrine can perform tasks like generating location, extracting
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

#### URL

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

### Persistence

Refile persists the uploaded file location and metadata into individual
columns:

* `<attachment>_id`
* `<attachment>_filename`
* `<attachment>_content_type`
* `<attachment>_size`

Shrine, on the other hand, saves all uploaded file data into a single
`<attachment>_data` column:

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
```rb
photo.image.id          #=> "path/to/image.jpg"
photo.image.storage_key #=> :store
photo.image.metadata    #=> { "filename" => "...", "size" => ..., "mime_type" => "..." }

photo.image.original_filename #=> "nature.jpg"
photo.image.size              #=> 4739472
photo.image.mime_type         #=> "image/jpeg"
```

This column can be queried if it's made a JSON column. Alternatively, you can
use the [`metadata_attributes`][metadata_attributes] plugin to save metadata
into separate columns.

### Processing

Shrine provides on-the-fly processing via the
[`derivation_endpoint`][derivation_endpoint] plugin:

```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount Shrine.derivation_endpoint => "/derivations"
end
```
```rb
require "image_processing/mini_magick"

Shrine.plugin :derivation_endpoint,
  secret_key: "<YOUR SECRET KEY>",
  prefix:     "derivations" # needs to match the mount point in routes

Shrine.derivation :thumbnail do |file, width, height|
  ImageProcessing::MiniMagick
    .source(file)
    .resize_to_limit!(width.to_i, height.to_i)
end
```

Shrine also support eager processing using the [`derivatives`][derivatives]
plugin.

### Validation

In Refile, file validation is defined statically on attachment definition:

```rb
class Photo < Sequel::Model
  attachment :image,
    extension: %w[jpg jpeg png webp],
    content_type: %w[image/jpeg image/png image/webp]
end
```

In Shrine, validation is performed on the instance-level, which allows you to
make the validation conditional:

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

Refile extracts the MIME type from the file extension, which means it can
easily be spoofed (just give a PHP file a `.jpg` extension). Shrine has the
[`determine_mime_type`][determine_mime_type] plugin for determining MIME type
from file *content*.

### Direct uploads

Shrine borrows Refile's idea of direct uploads, and ships with
`upload_endpoint` and `presign_endpoint` plugins which provide endpoints for
uploading files and generating presigns.

```rb
Shrine.plugin :upload_endpoint
Shrine.upload_endpoint(:cache) # Rack app that uploads files to specified storage

Shrine.plugin :upload_endpoint
Shrine.presign_endpoint(:cache) # Rack app that generates presigns for specified storage
```

While Refile ships with a plug-and-play JavaScript for direct uploads, Shrine
instead adopts [Uppy], a modern and modular JavaScript file upload library that
happens to integrate well with Shrine.

### Multiple uploads

Shrine doesn't have support for multiple uploads out-of-the-box like Refile
does. Instead, you can implement them using a separate table with a one-to-many
relationship to which the files will be attached. The [Multiple Files] guide
explains this setup in more detail.

## Migrating from Refile

You have an existing app using Refile and you want to transfer it to
Shrine. Let's assume we have a `Photo` model with the "image" attachment.

### 1. Add Shrine column

First we need to create the `image_data` column for Shrine:

```rb
add_column :photos, :image_data, :text
```

### 2. Dual write

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
    write_shrine_data(:image) if image_id_changed?
  end
end
```

After you deploy this code, the `image_data` column should now be successfully
synchronized with new attachments.

### 3. Data migration

Next step is to run a script which writes all existing Refile attachments to
`image_data`:

```rb
Photo.find_each do |photo|
  photo.write_shrine_data(:image)
  photo.save!
end
```

### 4. Rewrite code

Now you should be able to rewrite your application so that it uses Shrine
instead of Refile (you can consult the reference in the next section). You can
remove the `RefileShrineSynchronization` module as well.

### 5. Remove Refile columns

If everything is looking good, we can remove Refile columns:

```rb
remove_column :photos, :image_id
remove_column :photos, :image_size
remove_column :photos, :image_filename
remove_column :photos, :image_content_type
```

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

The Rack apps provided by the `*_endpoint` Shrine plugins are mounted
explicitly:

```rb
# config/routes.rb
Rails.application.routes.draw do
  # adds `POST /images/upload` endpoint
  mount ImageUploader.upload_endpoint(:cache) => "/images/upload"
end
```

#### `.allow_uploads_to`

The `Shrine.upload_endpoint` and `Shrine.presign_endpoint` builders require you
to specify the storage that will be used.

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

Shrine defines validations on the uploader class level:

```rb
class MyUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 5*1024*1024
  end
end
```

#### `.extract_filename`

Shrine's equivalent is a `Shrine#extract_filename` private method. You can
instead use the `Shrine#extract_metadata` public method.

#### `.extract_content_type`

The [`determine_mime_type`][determine_mime_type] plugin provides a
`Shrine.determine_mime_type` method.

#### `.app_url`, `.upload_url`, `.attachment_upload_url`, `.presign_url`, `.attachment_presign_url`

Shrine requires you to use your framework to generate URLs to mounted
endpoints.

#### `.attachment_url`, `.file_url`

You can call `#url` on the uploaded file, or `#<name>_url` on the model.
Alternatively, you can use `#download_url` provided by the `download_endpoint`
plugin.

#### `.host`, `.cdn_host`, `.app_host`, `.allow_downloads_from`, `allow_origin`, `.content_max_age`

These can be configured on individual `*_endpoint` plugins.

#### `.secret_key`, `.token`, `.valid_token?`

The secret key is required for the
[`derivation_endpoint`][derivation_endpoint], but these methods are not
exposed.

### `Attachment`

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

No equivalent in Shrine, but take a look at the [Multiple Files] guide.

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

[Uppy]: https://uppy.io
[derivation_endpoint]: https://shrinerb.com/docs/plugins/derivation_endpoint
[download_endpoint]: https://shrinerb.com/docs/plugins/download_endpoint
[derivatives]: https://shrinerb.com/docs/plugins/derivatives
[metadata_attributes]: https://shrinerb.com/docs/plugins/metadata_attributes
[determine_mime_type]: https://shrinerb.com/docs/plugins/determine_mime_type
[Multiple Files]: https://shrinerb.com/docs/multiple-files
