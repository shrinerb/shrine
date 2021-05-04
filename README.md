# [Shrine]

<img src="https://shrinerb.com/img/logo.png" width="100" alt="Shrine logo: a red paperclip" align="right" />

Shrine is a toolkit for handling file attachments in Ruby applications. Some highlights:

* **Modular design** – the [plugin system] allows you to load only the functionality you need
* **Memory friendly** – streaming uploads and [downloads][Retrieving Uploads] make it work great with large files
* **Cloud storage** – store files on [disk][FileSystem], [AWS S3][S3], [Google Cloud][GCS], [Cloudinary] and others
* **Persistence integrations** – works with [Sequel], [ActiveRecord], [ROM], [Hanami] and [Mongoid] and others
* **Flexible processing** – generate thumbnails [eagerly] or [on-the-fly] using [ImageMagick] or [libvips]
* **Metadata validation** – [validate files][validation] based on [extracted metadata][metadata]
* **Direct uploads** – upload asynchronously [to your app][simple upload] or [to the cloud][presigned upload] using [Uppy]
* **Resumable uploads** – make large file uploads [resumable][resumable upload] on [S3][uppy-s3_multipart] or [tus][tus-ruby-server]
* **Background jobs** – built-in support for [background processing][backgrounding] that supports [any backgrounding library][Backgrounding Libraries]

If you're curious how it compares to other file attachment libraries, see the
[Advantages of Shrine]. Otherwise, follow along with the **[Getting Started
guide]**.

## Links

| Resource                | URL                                                                            |
| :----------------       | :----------------------------------------------------------------------------- |
| Website & Documentation | [shrinerb.com](https://shrinerb.com)                                           |
| Demo code               | [Roda][roda demo] / [Rails][rails demo]                                        |
| Wiki                    | [github.com/shrinerb/shrine/wiki](https://github.com/shrinerb/shrine/wiki)     |
| Help & Discussion       | [discourse.shrinerb.com](https://discourse.shrinerb.com)                       |

## Setup

Add the gem to your Gemfile:

```rb
# Gemfile
gem "shrine", "~> 3.0"
```

Then add `config/initializers/shrine.rb` which sets up the storage and loads
ORM integration:

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"), # temporary
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads"),       # permanent
}

Shrine.plugin :activerecord           # loads Active Record integration
Shrine.plugin :cached_attachment_data # enables retaining cached file across form redisplays
Shrine.plugin :restore_cached_data    # extracts metadata for assigned cached files
```

Next, add the `<name>_data` column to the table you want to attach files to. For
an "image" attachment on a `photos` table this would be an `image_data` column:

```
$ rails generate migration add_image_data_to_photos image_data:text # or :jsonb
```
If using `jsonb` consider adding a [gin index] for fast key-value pair searchability within `image_data`.

Now create an uploader class (which you can put in `app/uploaders`) and
register the attachment on your model:

```rb
class ImageUploader < Shrine
  # plugins and uploading logic
end
```
```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image) # adds an `image` virtual attribute
end
```

In our views let's now add form fields for our attachment attribute that will
allow users to upload files:

```erb
<%= form_for @photo do |f| %>
  <%= f.hidden_field :image, value: @photo.cached_image_data %>
  <%= f.file_field :image %>
  <%= f.submit %>
<% end %>
```

When the form is submitted, in your controller you can assign the file from
request params to the attachment attribute on the model:

```rb
class PhotosController < ApplicationController
  def create
    Photo.create(photo_params) # attaches the uploaded file
    # ...
  end

  private

  def photo_params
    params.require(:photo).permit(:image)
  end
end
```

Once a file is uploaded and attached to the record, you can retrieve the file
URL and display it on the page:

```erb
<%= image_tag @photo.image_url %>
```

See the **[Getting Started guide]** for further documentation.

## Inspiration

Shrine was heavily inspired by [Refile] and [Roda]. From Refile it borrows the
idea of "backends" (here named "storages"), attachment interface, and direct
uploads. From Roda it borrows the implementation of an extensible plugin
system.

## Similar libraries

* Paperclip
* CarrierWave
* Dragonfly
* Refile
* Active Storage

## Contributing

Please refer to the [contributing page][Contributing].

## Code of Conduct

Everyone interacting in the Shrine project’s codebases, issue trackers, and
mailing lists is expected to follow the [Shrine code of conduct][CoC].

## License

The gem is available as open source under the terms of the [MIT License].

[Shrine]: https://shrinerb.com
[Advantages of Shrine]: https://shrinerb.com/docs/advantages
[plugin system]: https://shrinerb.com/docs/getting-started#plugin-system
[Retrieving Uploads]: https://shrinerb.com/docs/retrieving-uploads
[FileSystem]: https://shrinerb.com/docs/storage/file-system
[S3]: https://shrinerb.com/docs/storage/s3
[GCS]: https://github.com/renchap/shrine-google_cloud_storage
[Cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[Sequel]: https://shrinerb.com/docs/plugins/sequel
[ActiveRecord]: https://shrinerb.com/docs/plugins/activerecord
[ROM]: https://github.com/shrinerb/shrine-rom
[Hanami]: https://github.com/katafrakt/hanami-shrine
[Mongoid]: https://github.com/shrinerb/shrine-mongoid
[eagerly]: https://shrinerb.com/docs/getting-started#eager-processing
[on-the-fly]: https://shrinerb.com/docs/getting-started#on-the-fly-processing
[ImageMagick]: https://github.com/janko/image_processing/blob/master/doc/minimagick.md#readme
[libvips]: https://github.com/janko/image_processing/blob/master/doc/vips.md#readme
[validation]: https://shrinerb.com/docs/validation
[metadata]: https://shrinerb.com/docs/metadata
[simple upload]: https://shrinerb.com/docs/getting-started#simple-direct-upload
[presigned upload]: https://shrinerb.com/docs/getting-started#presigned-direct-upload
[resumable upload]: https://shrinerb.com/docs/getting-started#resumable-direct-upload
[Uppy]: https://uppy.io/
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[tus-ruby-server]: https://github.com/janko/tus-ruby-server
[backgrounding]: https://shrinerb.com/docs/plugins/backgrounding
[Backgrounding Libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
[Getting Started guide]: https://shrinerb.com/docs/getting-started
[roda demo]: /demo
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[Refile]: https://github.com/refile/refile
[Roda]: https://github.com/jeremyevans/roda
[CoC]: /CODE_OF_CONDUCT.md
[MIT License]: /LICENSE.txt
[Contributing]: https://github.com/shrinerb/shrine/blob/master/CONTRIBUTING.md
[gin index]: https://www.postgresql.org/docs/current/datatype-json.html#JSON-INDEXING
