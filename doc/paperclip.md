# Shrine for Paperclip Users

This guide is aimed at helping Paperclip users transition to Shrine, and it
consists of three parts:

1. Explanation of the key differences in design between Paperclip and Shrine
2. Instructions how to migrate and existing app that uses Paperclip to Shrine
3. Extensive reference of Paperclip's interface with Shrine equivalents

## Storages

In Paperclip the storage is configure inside the global options:

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

In contrast, a Shrine storage is just a class which you configure individually:

```rb
Shrine.storages[:store] = Shrine::Storage::S3.new(
  bucket:            "my-bucket",
  access_key_id:     "abc",
  secret_access_key: "xyz",
  region:            "eu-west-1",
)
```

Paperclip doesn't have a concept of "temporary" storage, so it cannot retain
uploaded files in case of validation errors, and [direct S3 uploads] cannot be
implemented in a safe way. Shrine uses separate "temporary" and "permanent"
storage for attaching files:

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::S3.new(bucket: "my-bucket", **s3_options),
}
```

## Uploaders

While in Paperclip you define all your uploading logic inside your models,
Shrine takes a more object-oriented approach and lets you define uploading logic
inside "uploader" classes:

```rb
class Photo < ActiveRecord::Base
  has_attached_file :image
end
```

```rb
class ImageUploader < Shrine
  # ...
end

class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image)
end
```

Among other things, this allows you to use uploader classes standalone, which
gives you more power:

```rb
uploaded_file = ImageUploader.upload(File.open("nature.jpg"), :store)
uploaded_file     #=> #<Shrine::UploadedFile>
uploaded_file.url #=> "https://my-bucket.s3.amazonaws.com/store/kfds0lg9rer.jpg"
```

### Processing

In contrast to Paperclip's static options, in Shrine you define and perform
processing on instance-level. You also have the descriptive method names
provided by the [image_processing] gem.


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

#### Reprocessing versions

Shrine doesn't have a built-in way of regenerating versions, because that has
to be written and optimized differently depending on whether you're adding or
removing a version, what ORM are you using, how many records there are in the
database etc. The [Managing Derivatives] guide provides some useful tips on
this task.

### Validations

Validations are also defined inside the uploader on the instance-level, which
allows you to do conditional validations:

```rb
class Photo < ActiveRecord::Base
  has_attached_file :image
  validates_attachment :image,
    content_type: {content_type: %w[image/jpeg image/png image/gif]},
    size: {in: 0..10.megabytes}
end
```

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type %w[image/jpeg image/gif image/png]
    validate_max_size 10*1024*1024
  end
end
```

#### MIME type spoofing

Paperclip detects MIME type spoofing, in the way that it extracts the MIME type
from file contents using the `file` command and MimeMagic, compares it to the
value that the `mime-types` gem determined from file extension, and raises a
validation error if these two values mismatch.

However, this turned out to be very problematic, leading to a lot of valid
files being classified as "spoofed", because of the differences of MIME
type databases between the `mime-types` gem, `file` command, and MimeMagic.

Shrine takes a different approach here. By default it will extract MIME
type from file extension, but it has a plugin for determining MIME type from
file contents, which by default uses the `file` command:

```rb
Shrine.plugin :determine_mime_type
```

However, it doesn't try to compare this value with the one from file extension,
it just means that now this value will be used for your MIME type validations.
With this approach you can still prevent malicious files from being attached,
but without the possibility of false negatives.

### Logging

In Paperclip you enable logging by setting `Paperclip.options[:log] = true`,
however, this only logs ImageMagick commands. Shrine has full logging support,
which measures processing, uploading and deleting individually:

```rb
Shrine.plugin :instrumentation
```
```
Metadata (32ms) – {:storage=>:store, :io=>StringIO, :uploader=>Shrine}
Upload (1523ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :io=>StringIO, :upload_options=>{}, :uploader=>Shrine}
Exists (755ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :uploader=>Shrine}
Download (1002ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :download_options=>{}, :uploader=>Shrine}
Delete (700ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :uploader=>Shrine}
```

## Attachments

While Paperclip is designed to only integrate with ActiveRecord, Shrine is
designed to be completely generic and integrate with any ORM. It ships with
plugins for ActiveRecord and Sequel:

```rb
Shrine.plugin :activerecord # if you're using ActiveRecord
Shrine.plugin :sequel       # if you're using Sequel
```

Instead of giving you class methods for defining attachments, in Shrine you
generate attachment modules which you simply include in your models, which
gives your models similar set of methods that Paperclip gives:

```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment(:image)
end
```

### Attachment column

Unlike in Paperclip which requires you to have 4 `<attachment>_*` columns, in
Shrine you only need to have a single `<attachment>_data` text column (in the
above case `image_data`), and all information will be stored there.

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

Unlike Paperclip, Shrine will store this information for each processed
version, making them first-class citizens:

```rb
photo.image               #=> #<Shrine::UploadedFile>
photo.image.width         #=> 800

photo.image(:thumb)       #=> #<Shrine::UploadedFile>
photo.image(:thumb).width #=> 300
```

Also, since Paperclip stores only the filename, it has to recalculate the full
location each time it wants to generate the URL. That makes it really difficult
to move files to a new location, because changing how the location is generated
will now cause incorrect URLs to be generated for all existing files. Shrine
calculates the whole location only once and saves it to the column.

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
require "shrine"

Shrine.storages = {
  cache: ...,
  store: ...,
}

Shrine.plugin :model
Shrine.plugin :derivatives
```
```rb
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

      attachment.styles.each do |name, style|
        attacher.merge_derivatives(name => shrine_file(style))
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
  def style_to_shrine_data(style)
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
synchronized with new attachments.  Next step is to run a script which writes
all existing Paperclip attachments to `image_data`:

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

You'll notice that Shrine metadata will be absent from the migrated files' data
(specifically versions). You can run a script that will fill in any missing
metadata defined in your Shrine uploader:

```rb
Shrine.plugin :refresh_metadata

Photo.find_each do |photo|
  photo.image_attacher.refresh_metadata!
  photo.save
end
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

#### `:default_url`

For default URLs you can use the `default_url` plugin:

```rb
class ImageUploader < Shrine
  plugin :default_url

  Attacher.default_url do |options|
    "/attachments/#{name}/default.jpg"
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
  def generate_location(io, **options)
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
photo.image_derivatives #=>
# {
#   small:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   large:  #<Shrine::UploadedFile>,
# }

photo.image(:small).url #=> "..."
# or
photo.image_url(:small) #=> "..."
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

The built-in [`Shrine::Storage::S3`] storage is a direct replacement for
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

#### `:s3_headers`

The object data can be configured via the `:upload_options` hash:

```rb
Shrine::Storage::S3.new(upload_options: { content_disposition: "attachment" }, **options)
```

You can use the `upload_options` plugin to set upload options dynamically.

#### `:s3_permissions`

The object permissions can be configured with the `:acl` upload option:

```rb
Shrine::Storage::S3.new(upload_options: { acl: "private" }, **options)
```

You can use the `upload_options` plugin to set upload options dynamically.

#### `:s3_metadata`

The object metadata can be configured with the `:metadata` upload option:

```rb
Shrine::Storage::S3.new(upload_options: { metadata: { "key" => "value" } }, **options)
```

You can use the `upload_options` plugin to set upload options dynamically.

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

[file]: http://linux.die.net/man/1/file
[Managing Derivatives]: /doc/changing_derivatives.md#readme
[direct S3 uploads]: /doc/direct_s3.md#readme
[`Shrine::Storage::S3`]: /doc/storage/s3.md#readme
[image_processing]: https://github.com/janko/image_processing
