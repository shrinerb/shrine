# Shrine for Refile Users

This guide is aimed at helping Refile users transition to Shrine. We will first
generally mention what are the key differences, and afterwards we will give a
complete reference of Refile's interface and note what is the equivalent in
Shrine.

## Uploaders

Shrine has the concept of storages very similar to Refile's backends. However,
while in Refile you usually work with storages directly, in Shrine you use
*uploaders* which act as wrappers around storages, and they are subclasses of
`Shrine`:

```rb
require "shrine/storage/file_system"
require "shrine/storage/s3"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(*args),
  store: Shrine::Storage::S3.new(*args),
}
```
```rb
class ImageUploader < Shrine
  # uploading logic
end
```

While in Refile you configure attachments by passing options to `.attachment`,
in Shrine you define all your uploading logic inside uploaders, and then
generate an attacment module with that uploader which is included into the
model:

```rb
class ImageUploader < Shrine
  plugin :store_dimensions
  plugin :determine_mime_type
  plugin :keep_files, destroyed: true
end
```
```rb
class User
  include ImageUploader[:avatar] # requires "avatar_data" column
end
```

Unlike Refile which has just a few options of configuring attachments, Shrine
has a very rich arsenal of features via plugins, and allows you to share your
uploading logic between uploaders through inheritance.

### ORMs

In Refile you extend the model with an Attachment module specific to the ORM
you're using. In Shrine you load the appropriate ORM plugin:

```rb
Shrine.plugin :sequel # or :activerecord
```
```rb
class Photo < Sequel::Model
  include ImageUploader[:image]
end
```

These integrations work much like Refile; on assignment the file is cached,
and on saving the record file is moved from cache to store. Shrine doesn't
provide form helpers for Rails, because it's so easy to do it yourself:

```erb
<%= form_for @photo do |f| %>
  <%= f.hidden_field :image, value: @photo.image_data %>
  <%= f.file_field :image %>
<% end %>
```

### URLs

To get file URLs, in Shrine you just call `#url` on the file:

```rb
@photo.image.url
@photo.image_url # returns nil if attachment is missing
```

If you're using storages which don't expose files over URL, or you want to
secure your downloads, you can use the `download_endpoint` plugin.

### Metadata

While in Refile you're required to have a separate column for each metadata you
want to save (filename, size, content type), in Shrine all of the metadata are
stored in a single column (for "avatar" it's `avatar_data` column) as JSON.

```rb
user.avatar_data #=> "{\"storage\":\"cache\",\"id\":\"9260ea09d8effd.jpg\",\"metadata\":{...}}"
```

By default Shrine stores "filename", "size" and "mime_type" metadata, but you
can also store image dimensions by loading the `store_dimensions` plugin.

### Processing

One of the key differences between Refile and Shrine is that in Refile you do
processing on-the-fly (like Dragonfly), while in Shrine you do your processing
on upload (like CarrierWave and Paperclip). However, there are storages which
you can use which support on-the-fly processing, like [shrine-cloudinary] or
[shrine-imgix].

In Shrine you do processing by overriding the `#process` method on your
uploader (for images you can use the [image_processing] gem):

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick

  def process(io, context)
    case context[:phase]
    when :store
      resize_to_fit!(io.download, 700, 700)
    end
  end
end
```

### Validations

While in Refile you can do extension, mime type and filesize validation by
passing options to `.attachment`, in Shrine you do this logic instance level,
with the help of the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_mime_type_inclusion ["image/jpeg", "image/png", "image/gif"]
  end
end
```

### Direct uploads

Shrine borrows Refile's idea of direct uploads, and ships with a
`direct_upload` plugin which provides the endpoint that you can mount:

```rb
class ImageUploader < Shrine
  plugin :direct_upload
end
```
```rb
# config/routes.rb
Rails.application.routes.draw do
  mount ImageUploader::UploadEndpoint => "/attachments/images"
end
```
```rb
# POST /attachments/images/cache/upload
{
  "id": "43kewit94.jpg",
  "storage": "cache",
  "metadata": {
    "size": 384393,
    "filename": "nature.jpg",
    "mime_type": "image/jpeg"
  }
}
```

Unlike Refile, Shrine doesn't ship with a JavaScript script which you can just
include to make it work. Instead, you're expected to use one of the many
excellent JavaScript libraries for generic file uploads, for example
[jQuery-File-Upload].

#### Presigned S3 uploads

The `direct_upload` plugin also provides an endpoint for getting S3 presigns,
you just need to pass the `presign: true` option. In the same way as with regular
direct uploads, you can use a generic JavaScript file upload library. For the
details read the [Direct Uploads to S3] guide.

### Multiple uploads

Shrine doesn't have a built-in solution for accepting multiple uploads, but
it's actually very easy to do manually, see the [example app] on how you can do
multiple uploads directly to S3.

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
module RefileShrineSynchronization
  def write_shrine_data(name)
    if read_attribute("#{name}_id").present?
      data = {
        storage: :store,
        id: send("#{name}_id"),
        metadata: {
          size: (send("#{name}_size") if respond_to?("#{name}_size")),
          filename: (send("#{name}_filename") if respond_to?("#{name}_filename")),
          mime_type: (send("#{name}_content_type") if respond_to?("#{name}_content_type")),
        }
      }

      write_attribute(:"#{name}_data", data.to_json)
    else
      write_attribute(:"#{name}_data", nil)
    end
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

The `direct_upload` plugin provides a subset of Refile's app's functionality,
and you have to mount it in your framework's router:

```rb
# config/routes.rb
Rails.application.routes.draw do
  # adds `POST /attachments/images/:storage/:name`
  mount ImageUploader::UploadEndpoint => "/attachments/images"
end
```

#### `.allow_uploads_to`

```rb
Shrine.plugin :direct_upload, storages: [:cache]
```

#### `.logger`

```rb
Shrine.plugin :logging
```

#### `.processors`, `.processor`

In Shrine processing is done by overriding the `#process` method in your
uploader:

```rb
class MyUploader < Shrine
  def process(io, context)
    # ...
  end
end
```

#### `.types`

In Shrine validations are done by calling `.validate` on the attacher class:

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
enpdoint.

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
class User
  include ImageUploader[:avatar]
end
```

#### `:extension`, `:content_type`, `:type`

In Shrine validations are done instance-level inside the uploader, most
commonly with the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_extension_inclusion [/jpe?g/, "png"]
    validate_mime_type_inclusion ["image/jpeg", "image/png"]
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

[shrine-cloudinary]: https://github.com/janko-m/shrine-cloudinary
[shrine-imgix]: https://github.com/janko-m/shrine-imgix
[image_processing]: https://github.com/janko-m/image_processing
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
[Direct Uploads to S3]: http://shrinerb.com/rdoc/files/doc/direct_s3_md.html
[example app]: https://github.com/janko-m/shrine-example
