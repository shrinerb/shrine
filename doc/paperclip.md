---
title: Upgrading from Paperclip
---

This guide is aimed at helping Paperclip users transition to Shrine, and it
consists of three parts:

1. Explanation of the key differences in design between Paperclip and Shrine
2. Instructions how to migrate an existing app that uses Paperclip to Shrine
3. Extensive reference of Paperclip's interface with Shrine equivalents

## Overview

### Uploader

In Paperclip, the attachment logic is configured directly inside Active Record
models:

```rb
class Photo < ActiveRecord::Base
  has_attached_file :image,
    preserve_files: true,
    default_url:    "/images/:style/missing.png"

  validated_attachment_content_type :image, content_type: "image/jpeg"
end
```

Shrine takes a more object-oriented approach, by encapsulating attachment logic
in "uploader" classes:

```rb
class ImageUploader < Shrine
  plugin :keep_files
  plugin :default_url
  plugin :validation_helpers

  Attacher.default_url do |derivative: nil, **|
    "/images/#{derivative}/missing.png" if derivative
  end

  Attacher.validate do
    validate_mime_type %w[image/jpeg]
  end
end
```
```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image)
end
```

### Storage

Paperclip storage is configured together with other attachment options. Also,
the storage implementations themselves are mixed into the attachment class,
which couples them to the attachment flow.

```rb
class Photo < ActiveRecord::Base
  has_attached_file :image,
    storage: :s3,
    s3_credentials: {
      bucket:            "my-bucket",
      access_key_id:     "abc",
      secret_access_key: "xyz",
    },
    s3_region: "eu-west-1",
end
```

Shrine storage objects are configured separately and are decoupled from
attachment:

```rb
Shrine.storages[:store] = Shrine::Storage::S3.new(
  bucket:            "my-bucket",
  access_key_id:     "abc",
  secret_access_key: "xyz",
  region:            "eu-west-1",
)
```

Shrine also has a concept of "temporary" storage, which enables retaining
uploaded files in case of validation errors and [direct uploads].

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::S3.new(bucket: "my-bucket", **s3_options),
}
```

### Persistence

When using Paperclip, the attached file data will be persisted into several
columns:

* `<name>_file_name`
* `<name>_content_type`
* `<name>_file_size`
* `<name>_updated_at`
* `<name>_created_at` (optional)
* `<name>_fingerprint` (optional)

In contrast, Shrine uses a single `<name>_data` column to store data in JSON
format:

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

#### ORM

While Paperclip works only with Active Record, Shrine is designed to integrate
with any persistence library (there are integrations for [Active
Record][activerecord], [Sequel][sequel], [ROM][rom], [Hanami][hanami] and
[Mongoid][mongoid]), and can also be used standalone:

```rb
attacher = ImageUploader::Attacher.new
attacher.attach File.open("nature.jpg")
attacher.file #=> #<Shrine::UploadedFile id="f4ba5bdbf366ef0b.jpg" ...>
attacher.url  #=> "https://my-bucket.s3.amazonaws.com/f4ba5bdbf366ef0b.jpg"
attacher.data #=> { "id" => "f4ba5bdbf366ef0b.jpg", "storage" => "store", "metadata" => { ... } }
```

#### Location

Paperclip persists only the filename of the uploaded file, and recalculates the
full location dynamically based on location configuration. This can be
dangerous, because if some component of the location happens to change, all
existing links might become invalid.

To avoid this, Shrine persists the full location on attachment, and uses it
when generating file URL. So, even if you change how file locations are
generated, existing files that are on old locations will still remain
accessible.

### Processing

In Shrine, processing is defined and performed on the instance level, which
gives you more control. You're also not coupled to ImageMagick, e.g. you can
use [libvips] instead (both integrations are provided by the [image_processing]
gem).

```rb
class Photo < ActiveRecord::Base
  has_attached_file :image,
    styles: {
      large:  "800x800>",
      medium: "500x500>",
      small:  "300x300>",
    }
end
```

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :derivatives

  Attacher.derivatives do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    {
      large:  magick.resize_to_limit!(800, 800),
      medium: magick.resize_to_limit!(500, 500),
      small:  magick.resize_to_limit!(300, 300),
    }
  end
end
```

Shrine is agnostic as to how you're performing your processing, so you can
easily use any other processing tools. You can also combine different
processors for different versions.

#### Retrieving versions

When retrieving versions, Paperclip returns a list of declared styles which
may or may not have been generated. In contrast, Shrine persists data of
uploaded processed files into the database (including any extracted metadata),
which then becomes the source of truth on which versions have been generated.

```rb
photo.image              #=> #<Shrine::UploadedFile id="original.jpg" ...>
photo.image_derivatives  #=> {}

photo.image_derivatives! # triggers processing
photo.image_derivatives  #=>
# {
#   large: #<Shrine::UploadedFile id="large.jpg" metadata={"size"=>873232, ...} ...>,
#   medium: #<Shrine::UploadedFile id="medium.jpg" metadata={"size"=>94823, ...} ...>,
#   small: #<Shrine::UploadedFile id="small.jpg" metadata={"size"=>37322, ...} ...>,
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
class Photo < ActiveRecord::Base
  has_attached_file :image
  validates_attachment :image,
    size: { in: 0..10.megabytes },
    content_type: { content_type: %w[image/jpeg image/png image/webp] }
end
```

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10*1024*1024

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

#### MIME type spoofing

Paperclip attempts to detect MIME type spoofing, which turned out to be
unreliable due to differences in MIME type databases between different ruby
libraries.

Shrine on the other hand simply allows you to determine MIME type from file
content, which you can then validate.

```rb
Shrine.plugin :determine_mime_type, analyzer: :marcel
```
```rb
file = uploader.upload StringIO.new("<?php ... ?>")
file.mime_type #=> "application/x-php"
```

## Migrating from Paperclip

You have an existing app using Paperclip and you want to transfer it to Shrine.
Let's assume we have a `Photo` model with the "image" attachment.

### 1. Add Shrine column

First we need to create the `image_data` column for Shrine:

```rb
add_column :photos, :image_data, :text
```

### 2. Dual write

Next, we need to make new Paperclip attachments write to the `image_data`
column. This can be done by including the below module to all models that have
Paperclip attachments:

```rb
require "shrine"

Shrine.storages = {
  cache: ...,
  store: ...,
}

Shrine.plugin :model
Shrine.plugin :derivatives

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
    attacher   = Shrine::Attacher.from_model(self, name)

    if attachment.size.present?
      attacher.set shrine_file(attachment)

      attachment.styles.each do |style_name, style|
        attacher.merge_derivatives(style_name => shrine_file(style))
      end
    else
      attacher.set nil
    end
  end

  private

  def shrine_file(object)
    if object.is_a?(Paperclip::Attachment)
      shrine_attachment_file(object)
    else
      shrine_style_file(object)
    end
  end

  # If you'll be using a `:prefix` on your Shrine storage, or you're storing
  # files on the filesystem, make sure to subtract the appropriate part
  # from the path assigned to `:id`.
  def shrine_attachment_file(attachment)
    Shrine.uploaded_file(
      storage:  :store,
      id:       attachment.path,
      metadata: {
        "size"      => attachment.size,
        "filename"  => attachment.original_filename,
        "mime_type" => attachment.content_type,
      }
    )
  end

  # If you'll be using a `:prefix` on your Shrine storage, or you're storing
  # files on the filesystem, make sure to subtract the appropriate part
  # from the path assigned to `:id`.
  def shrine_style_file(style)
    Shrine.uploaded_file(
      storage:  :store,
      id:       style.attachment.path(style.name),
      metadata: {},
    )
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
synchronized with new attachments.

### 3. Data migration

Next step is to run a script which writes all existing Paperclip attachments to
`image_data`:

```rb
Photo.find_each do |photo|
  photo.write_shrine_data(:image)
  photo.save!
end
```

### 4. Rewrite code

Now you should be able to rewrite your application so that it uses Shrine
instead of Paperclip (you can consult the reference in the next section). You
can remove the `PaperclipShrineSynchronization` module as well.

### 5. Remove Paperclip columns

If everything is looking good, we can remove Paperclip columns:

```rb
remove_column :photos, :image_file_name
remove_column :photos, :image_file_size
remove_column :photos, :image_content_type
remove_column :photos, :image_updated_at
```

## Paperclip to Shrine direct mapping

### `has_attached_file`

As mentioned above, Shrine's equivalent of `has_attached_file` is including
an attachment module:

```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment(:image) # adds `image`, `image=` and `image_url` methods
end
```

Now we'll list all options that `has_attached_file` accepts, and explain
Shrine's equivalents:

#### `:storage`

In Shrine attachments will automatically use `:cache` and `:store` storages
which you have to register:

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads"),
}
```

You can change that for a specific uploader with the `default_storage` plugin.

#### `:styles`, `:processors`, `:convert_options`

Processing is defined by using the `derivatives` plugin:

```rb
class ImageUploader < Shrine
  plugin :derivatives

  Attacher.derivatives do |original|
    magick = ImageProcessing::MiniMagick.source(original)

    {
      large:  magick.resize_to_limit!(800, 800),
      medium: magick.resize_to_limit!(500, 500),
      small:  magick.resize_to_limit!(300, 300),
    }
  end
end
```

#### `:default_url`

For default URLs you can use the `default_url` plugin:

```rb
class ImageUploader < Shrine
  plugin :default_url

  Attacher.default_url do |derivative: nil, **|
    "/images/placeholders/#{derivative || "original"}.jpg"
  end
end
```

#### `:preserve_files`

Shrine provides a `keep_files` plugin which allows you to keep files that would
otherwise be deleted:

```rb
Shrine.plugin :keep_files
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
  def generate_location(io, record: nil, name: nil, **)
    [ storage_key,
      record && record.class.name.underscore,
      record && record.id,
      super,
      io.original_filename ].compact.join("/")
  end
end
```
```
cache/user/123/2feff8c724e7ce17/nature.jpg
store/user/456/7f99669fde1e01fc/kitten.jpg
...
```

#### `:validate_media_type`

Shrine has this functionality in the `determine_mime_type` plugin.

### `validates_attachment`

#### `:presence`

For presence validation you can use your ORM's presence validator:

```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image)
  validates_presence_of :image
end
```

#### `:content_type`

You can do MIME type validation with Shrine's `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type %w[image/jpeg image/png image/webp]
  end
end
```

Make sure to also load the `determine_mime_type` plugin to detect MIME type
from file content.

```rb
# Gemfile
gem "mimemagic"
```
```rb
Shrine.plugin :determine_mime_type, analyzer: -> (io, analyzers) do
  analyzers[:mimemagic].call(io) || analyzers[:file].call(io)
end
```

#### `:size`

You can do filesize validation with Shrine's `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 10*1024*1024
  end
end
```

### `Paperclip::Attachment`

This section explains the equivalent of Paperclip attachment's methods, in
Shrine this is an instance of `Shrine::UploadedFile`.

#### `#url`

In Shrine you can generate URLs with `#<name>_url`:

```rb
photo.image_url         #=> "https://example.com/path/to/original.jpg"
photo.image_url(:large) #=> "https://example.com/path/to/large.jpg"
```

#### `#styles`

In Shrine you can use `#<name>_derivatives` to retrieve a list of versions:

```rb
photo.image_derivatives #=>
# {
#   small:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   large:  #<Shrine::UploadedFile>,
# }

photo.image_derivatives[:small] #=> #<Shrine::UploadedFile>
# or
photo.image(:small) #=> #<Shrine::UploadedFile>
```

#### `#path`

Shrine doesn't have this because storages are abstract and this would be
specific to the filesystem, but the closest is probably `#id`:

```rb
photo.image.id #=> "photo/342/image/398543qjfdsf.jpg"
```

#### `#reprocess!`

Shrine doesn't have an equivalent to this, but the [Managing Derivatives]
guide provides some useful tips on how to do this.

### `Paperclip::Storage::S3`

The built-in [`Shrine::Storage::S3`][S3] storage is a direct replacement for
`Paperclip::Storage::S3`.

#### `:s3_credentials`, `:s3_region`, `:bucket`

The Shrine storage accepts `:access_key_id`, `:secret_access_key`, `:region`,
and `:bucket` options in the initializer:

```rb
Shrine::Storage::S3.new(
  access_key_id:     "...",
  secret_access_key: "...",
  region:            "...",
  bucket:            "...",
)
```

#### `:s3_headers`, `:s3_permissions`, `:s3_metadata`

These can be configured via the `:upload_options` option:

```rb
Shrine::Storage::S3.new(
  upload_options: {
    content_disposition: "attachment",         # headers
    acl:                 "private",            # permissions
    metadata:            { "key" => "value" }, # metadata
  },
  **options
)
```

#### `:s3_protocol`, `:s3_host_alias`, `:s3_host_name`

The `#url` method accepts a `:host` option for specifying a CDN host. You can
use the `url_options` plugin to set it by default:

```rb
Shrine.plugin :url_options, store: { host: "http://abc123.cloudfront.net" }
```

#### `:path`

The `#upload` method accepts the destination location as the second argument.

```rb
s3 = Shrine::Storage::S3.new(**options)
s3.upload(io, "object/destination/path")
```

#### `:url`

The Shrine storage has no replacement for the `:url` Paperclip option, and it
isn't needed.

[Managing Derivatives]: https://shrinerb.com/docs/changing-derivatives
[direct uploads]: https://shrinerb.com/docs/getting-started#direct-uploads
[S3]: https://shrinerb.com/docs/storage/s3
[image_processing]: https://github.com/janko/image_processing
[libvips]: http://libvips.github.io/libvips/
[activerecord]: https://shrinerb.com/docs/plugins/activerecord
[sequel]: https://shrinerb.com/docs/plugins/sequel
[rom]: https://github.com/shrinerb/shrine-rom
[hanami]: https://github.com/katafrakt/hanami-shrine
[mongoid]: https://github.com/shrinerb/shrine-mongoid
