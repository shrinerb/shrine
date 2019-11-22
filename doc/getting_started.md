---
id: getting-started
title: Getting Started
---

## Quick start

Add Shrine to the Gemfile and write an initializer which sets up the storage
and loads integration for your persistence library:

```rb
# Gemfile
gem "shrine", "~> 3.0"
```

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"), # temporary
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads"),       # permanent
}

Shrine.plugin :sequel # or :activerecord
Shrine.plugin :cached_attachment_data # for retaining the cached file across form redisplays
Shrine.plugin :restore_cached_data # re-extract metadata when attaching a cached file
Shrine.plugin :rack_file # for non-Rails apps
```

Next decide how you will name the attachment attribute on your model, and run a
migration that adds an `<attachment>_data` text or JSON column, which Shrine
will use to store all information about the attachment:

<!--DOCUSAURUS_CODE_TABS-->
<!--Sequel-->
```rb
Sequel.migration do
  change do
    add_column :photos, :image_data, :text # or :jsonb
  end
end
```
<!--ActiveRecord-->
```rb
class AddImageDataToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :image_data, :text # or :jsonb
  end
end
```
<!--Rails-->
```
$ rails generate migration add_image_data_to_photos image_data:text
```
<!--END_DOCUSAURUS_CODE_TABS-->

Now you can create an uploader class for the type of files you want to upload,
and add a virtual attribute for handling attachments using this uploader to
your model. If you do not care about adding plugins or additional processing,
you can use `Shrine::Attachment`.

```rb
class ImageUploader < Shrine
  # plugins and uploading logic
end
```
<!--DOCUSAURUS_CODE_TABS-->
<!--Sequel-->
```rb
class Photo < Sequel::Model
  include ImageUploader::Attachment(:image) # adds an `image` virtual attribute
end
```
<!--ActiveRecord-->
```rb
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image) # adds an `image` virtual attribute
end
```
<!--END_DOCUSAURUS_CODE_TABS-->

Let's now add the form fields which will use this virtual attribute (NOT the
`<attachment>_data` column attribute). We need (1) a file field for choosing
files, and (2) a hidden field for retaining the uploaded file in case of
validation errors and for potential [direct uploads].

<!--DOCUSAURUS_CODE_TABS-->
<!--Rails form builder-->
```rb
form_for @photo do |f|
  f.hidden_field :image, value: @photo.cached_image_data
  f.file_field :image
  f.submit
end
```
<!--Simple Form-->
```rb
simple_form_for @photo do |f|
  f.input :image, as: :hidden, input_html: { value: @photo.cached_image_data }
  f.input :image, as: :file
  f.button :submit
end
```
<!--Forme-->
```rb
form @photo, action: "/photos", enctype: "multipart/form-data" do |f|
  f.input :image, type: :hidden, value: @photo.cached_image_data
  f.input :image, type: :file
  f.button "Create"
end
```
<!--END_DOCUSAURUS_CODE_TABS-->

Note that the file field needs to go *after* the hidden field, so that
selecting a new file can always override the cached file in the hidden field.
Also notice the `enctype="multipart/form-data"` HTML attribute, which is
required for submitting files through the form (the Rails form builder
will automatically generate this for you).

When the form is submitted, in your router/controller you can assign the file
from request params to the attachment attribute on the model.

<!--DOCUSAURUS_CODE_TABS-->
<!--Rails-->
```rb
class PhotosController < ApplicationController
  def create
    Photo.create(photo_params)
    # ...
  end

  private

  def photo_params
    params.require(:photo).permit(:image)
  end
end
```
<!--Sinatra-->
```rb
post "/photos" do
  Photo.create(params[:photo])
  # ...
end
```
<!--END_DOCUSAURUS_CODE_TABS-->

Once a file is uploaded and attached to the record, you can retrieve a URL to
the uploaded file with `#<attachment>_url` and display it on the page:

<!--DOCUSAURUS_CODE_TABS-->
<!--Rails-->
```erb
<%= image_tag @photo.image_url %>
```
<!--HTML-->
```erb
<img src="<%= @photo.image_url %>" />
```
<!--END_DOCUSAURUS_CODE_TABS-->

## Storage

A "storage" in Shrine is an object that encapsulates communication with a
specific storage service, by implementing a common public interface. Storage
instances are registered under an identifier in `Shrine.storages`, so that they
can later be used by [uploaders][uploader].

Shrine ships with the following storages:

* [`Shrine::Storage::FileSystem`][FileSystem] – stores files on disk
* [`Shrine::Storage::S3`][S3] – stores files on [AWS S3] (or [DigitalOcean Spaces], [MinIO], ...)
* [`Shrine::Storage::Memory`][Memory] – stores file in memory (convenient for [testing][Testing with Shrine])

Here is how we might configure Shrine with S3 storage:

```rb
# Gemfile
gem "aws-sdk-s3", "~> 1.14" # for AWS S3 storage
```
```rb
require "shrine/storage/s3"

s3_options = {
  bucket:            "<YOUR BUCKET>", # required
  region:            "<YOUR REGION>", # required
  access_key_id:     "<YOUR ACCESS KEY ID>",
  secret_access_key: "<YOUR SECRET ACCESS KEY>",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options), # temporary
  store: Shrine::Storage::S3.new(**s3_options),                  # permanent
}
```

The above example sets up S3 for both temporary and permanent storage, which is
suitable for [direct uploads][presigned upload]. The `:cache` and `:store`
names are special only in terms that the [attacher] will automatically pick
them up, you can also register more storage objects under different names.

See the [FileSystem]/[S3]/[Memory] storage docs for more details. There are
[many more Shrine storages][storages] provided by external gems, and you can
also [create your own storage][Creating Storages].

## Uploader

Uploaders are subclasses of `Shrine`, and they wrap the actual upload to the
storage. They perform common tasks around upload that aren't related to a
particular storage.

```rb
class MyUploader < Shrine
  # image attachment logic
end
```

It's common to create an uploader for each type of file that you want to handle
(`ImageUploader`, `VideoUploader`, `AudioUploader` etc), but really you can
organize them in any way you like.

### Uploading

The main method of the uploader is `Shrine.upload`, which takes an [IO-like
object][io abstraction] and a storage identifier on the input, and returns a
representation of the [uploaded file] on the output.

```rb
MyUploader.upload(file, :store) #=> #<Shrine::UploadedFile>
```

Internally this instantiates the uploader with the storage and calls
`Shrine#upload`:

```rb
uploader = MyUploader.new(:store)
uploader.upload(file) #=> #<Shrine::UploadedFile>
```

Some of the tasks performed by `#upload` include:

* extracting [metadata]
* generating [location]
* uploading (this is where the [storage] is called)
* closing the uploaded file

The second argument is a "context" hash which is forwarded to places like
metadata extraction and location generation, but it has a few special options:

```rb
uploader.upload(io, metadata: { "foo" => "bar" })           # add metadata
uploader.upload(io, location: "path/to/file")               # specify custom location
uploader.upload(io, upload_options: { acl: "public-read" }) # add options to Storage#upload
```

### IO abstraction

Shrine is able to upload any IO-like object that implement methods [`#read`],
[`#rewind`], [`#eof?`] and [`#close`] whose behaviour matches the [`IO`] class.
This includes but is not limited to the following objects:

* [`File`](https://ruby-doc.org/core/File.html)
* [`Tempfile`](https://ruby-doc.org/stdlib/libdoc/tempfile/rdoc/Tempfile.html)
* [`StringIO`](https://ruby-doc.org/stdlib/libdoc/stringio/rdoc/StringIO.html)
* [`ActionDispatch::Http::UploadedFile`](https://api.rubyonrails.org/classes/ActionDispatch/Http/UploadedFile.html)
* [`Shrine::RackFile`](https://shrinerb.com/docs/plugins/rack_file)
* [`Shrine::DataFile`](https://shrinerb.com/docs/plugins/data_uri)
* [`Shrine::UploadedFile`](#uploaded-file)
* [`Down::ChunkedIO`](https://github.com/janko/down#streaming)
* ...

```rb
uploader.upload File.open("/path/to/file", binmode: true)   # upload from disk
uploader.upload StringIO.new("file content")                # upload from memory
uploader.upload ActionDispatch::Http::UploadedFile.new(...) # upload from Rails controller
uploader.upload Shrine.rack_file({ tempfile: tempfile })    # upload from Rack controller
uploader.upload Rack::Test::UploadedFile.new(...)           # upload from rack-test
uploader.upload Down.open("https://example.org/file")       # upload from internet
uploader.upload Shrine::UploadedFile.new(...)               # upload from Shrine storage
```

## Uploaded file

The `Shrine::UploadedFile` object represents the file that was uploaded to a
storage, and it's what's returned from `Shrine#upload` or when retrieving a
record [attachment].

```rb
uploader.upload(file) #=> #<Shrine::UploadedFile ...>  (uploader)
photo.image           #=> #<Shrine::UploadedFile ...>  (attachment)
attacher.file         #=> #<Shrine::UploadedFile ...>  (attacher)
```

An uploaded file object contains the following data:

| Key        | Description                                        |
| :-------   | :----------                                        |
| `id`       | location of the file on the storage                |
| `storage`  | identifier of the storage the file was uploaded to |
| `metadata` | file [metadata] that was extracted before upload   |

```rb
uploaded_file #=> #<Shrine::UploadedFile id="949sdjg834.jpg" storage=:store metadata={...}>

uploaded_file.id          #=> "949sdjg834.jpg"
uploaded_file.storage_key #=> :store
uploaded_file.storage     #=> #<Shrine::Storage::S3>
uploaded_file.metadata    #=> {...}
```

It comes with many convenient methods that delegate to the storage:

```rb
uploaded_file.url                     #=> "https://my-bucket.s3.amazonaws.com/949sdjg834.jpg"
uploaded_file.open { |io| ... }       # opens the uploaded file stream
uploaded_file.download { |file| ... } # downloads the uploaded file to disk
uploaded_file.stream(destination)     # streams uploaded content into a writable destination
uploaded_file.exists?                 #=> true
uploaded_file.delete                  # deletes the uploaded file from the storage
```

It also implements the IO-like interface that conforms to Shrine's [IO
abstraction][io abstraction], which allows it to be uploaded again to other
storages.

```rb
uploaded_file.read   # returns content of the uploaded file
uploaded_file.eof?   # returns true if the whole IO was read
uploaded_file.rewind # rewinds the IO
uploaded_file.close  # closes the IO
```

For more details, see the [Retrieving Uploads] guide and
[`Shrine::UploadedFile`] API docs.

## Attaching

To attach uploaded files to database records, Shrine offers an attachment
interface built on top of uploaders and uploaded files. There are integrations
for various persistence libraries ([ActiveRecord][activerecord plugin],
[Sequel][sequel plugin], [ROM][rom plugin], [Hanami][hanami plugin],
[Mongoid][mongoid plugin]), but you can also attach files to plain structs
([mutable][model plugin] or [immutable][entity plugin]).

```rb
Shrine.plugin :sequel # :activerecord
```

### Attachment module

The easiest way to attach files is with the `Shrine::Attachment` module:

```rb
class Photo < Sequel::Model # ActiveRecord::Base
  include ImageUploader::Attachment.new(:image) #
  include ImageUploader::Attachment[:image]     # use your preferred syntax
  include ImageUploader::Attachment(:image)     #
end
```

The included module will add attachment methods for the specified attribute:

| Method            | Description                                                                       |
| :-----            | :----------                                                                       |
| `#image=`         | uploads the file to temporary storage and serializes the result into `image_data` |
| `#image`          | returns [`Shrine::UploadedFile`][uploaded file] instantiated from `image_data`    |
| `#image_url`      | calls `url` on the attachment if it's present, otherwise returns nil              |
| `#image_attacher` | returns instance of [`Shrine::Attacher`][attacher] which handles the attaching    |

The persistence plugin we loaded will add callbacks that ensure cached files
are automatically promoted to permanent storage on when record is saved, and
that attachments are deleted when the record is destroyed.

```rb
# no file is attached
photo.image #=> nil

# the assigned file is cached to temporary storage and written to `image_data` column
photo.image = File.open("waterfall.jpg", "rb")
photo.image      #=> #<Shrine::UploadedFile ...>
photo.image_url  #=> "/uploads/cache/0sdfllasfi842.jpg"
photo.image_data #=> '{"id":"0sdfllasfi842.jpg","storage":"cache","metadata":{...}}'

# the cached file is promoted to permanent storage and saved to `image_data` column
photo.save
photo.image      #=> #<Shrine::UploadedFile ...>
photo.image_url  #=> "/uploads/store/l02kladf8jlda.jpg"
photo.image_data #=> '{"id":"l02kladf8jlda.jpg","storage":"store","metadata":{...}}'

# the attached file is deleted with the record
photo.destroy
photo.image.exists? #=> false
```

If there is already a file attached and a new file is attached, the previous
attachment will get deleted when the record gets saved.

```rb
photo.update(image: new_file) # changes the attachment and deletes previous
photo.update(image: nil)      # removes the attachment and deletes previous
```

### Attacher

The methods and callbacks added by the `Shrine::Attachment` module just
delegate the behaviour to an underlying `Shrine::Attacher` object.

```rb
photo.image_attacher #=> #<Shrine::Attacher>
```

The `Shrine::Attacher` object can be instantiated and used directly:

```rb
attacher = ImageUploader::Attacher.from_model(photo, :image)

attacher.assign(file) # equivalent to `photo.image = file`
attacher.file         # equivalent to `photo.image`
attacher.url          # equivalent to `photo.image_url`
```

The attacher is what drives attaching files to model instances; you can use it
as a more explicit alternative to models' attachment interface, or when you
need something that's not available through the attachment methods.

See [Using Attacher] guide for more details.

### Temporary storage

Shrine uses temporary storage to support retaining uploaded files across form
redisplays and [direct uploads]. But you can disable this behaviour, and have
files go straight to permanent storage:

```rb
Shrine.plugin :model, cache: false
```
```rb
photo.image = File.open("waterfall.jpg", "rb")
photo.image.storage_key #=> :store
```

If you're using the attacher directly, you can just use `Attacher#attach`
instead of `Attacher#assign`:

```rb
attacher.attach File.open("waterfall.jpg", "rb")
attacher.file.storage_key #=> :store
```

## Plugin system

By default Shrine comes with a small core which provides only the essential
functionality. All additional features are available via [plugins], which also
ship with Shrine. This way you can choose exactly what and how much Shrine does
for you, and you load the code only for features that you use.

```rb
Shrine.plugin :instrumentation # adds instrumentation
```

Plugins add behaviour by extending Shrine core classes via module inclusion, and
many of them also accept configuration options. The plugin system respects
inheritance, so you can choose to load a plugin globally or per uploader.

```rb
class ImageUploader < Shrine
  plugin :store_dimensions # extract image dimensions only for this uploader and its descendants
end
```

If you want to extend Shrine functionality with custom behaviour, you can also
[create your own plugin][Creating Plugins]. There are also additional [external
plugins] created by others.

## Metadata

Shrine automatically extracts some basic file metadata and saves them to the
`Shrine::UploadedFile`. You can access them through the `#metadata` hash or via
metadata methods:

```rb
uploaded_file.metadata #=>
# {
#   "filename" => "matrix.mp4",
#   "mime_type" => "video/mp4",
#   "size" => 345993,
# }

uploaded_file.original_filename #=> "matrix.mp4"
uploaded_file.extension         #=> "mp4"
uploaded_file.mime_type         #=> "video/mp4"
uploaded_file.size              #=> 345993
```

### MIME type

By default, `mime_type` metadata will be set from the `#content_type` attribute
of the uploaded file (if it exists), which is generally not secure and will
trigger a warning. You can load the [`determine_mime_type`][determine_mime_type
plugin] plugin to have MIME type extracted from file *content* instead.

```rb
# Gemfile
gem "marcel", "~> 0.3"
```
```rb
Shrine.plugin :determine_mime_type, analyzer: :marcel
```
```rb
photo = Photo.create(image: StringIO.new("<?php ... ?>"))
photo.image.mime_type #=> "application/x-php"
```

### Other metadata

In addition to basic metadata, you can also extract [image
dimensions][store_dimensions plugin], calculate [signatures][signature plugin],
and in general extract any [custom metadata][add_metadata plugin]. Check out
the [Extracting Metadata] guide for more details.

## Processing

Shrine allows you to process attached files both "eagerly" and "on-the-fly".
For example, if your app is accepting image uploads, you can generate a
predefined set of of thumbnails when the image is attached to a record, or you
can have thumbnails generated dynamically as they're needed.

For image processing, it's recommended to use the **[ImageProcessing]** gem,
which is a high-level wrapper for processing with
[MiniMagick][ImageProcessing::MiniMagick] and [libvips][ImageProcessing::Vips].

```
$ brew install imagemagick vips
```

### Eager processing

You can use the [`derivatives`][derivatives plugin] plugin to generate a
pre-defined set of processed files:

```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
```rb
Shrine.plugin :derivatives
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
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
```rb
photo = Photo.new(image: file)
photo.image_derivatives! # calls derivatives processor and uploads results
photo.save
```

If you're allowing the attached file to be updated later on, in your update
route make sure to trigger derivatives creation for new attachments:

```rb
photo.image_derivatives! if photo.image_changed?
```

After the processed files are uploaded, their data is saved into the
`<attachment>_data` column. You can then retrieve the derivatives as
[`Shrine::UploadedFile`][uploaded file] objects:

```rb
photo.image(:large)            #=> #<Shrine::UploadedFile ...>
photo.image(:large).url        #=> "/uploads/store/lg043.jpg"
photo.image(:large).size       #=> 5825949
photo.image(:large).mime_type  #=> "image/jpeg"
```

For more details, see the [`derivatives`][derivatives plugin] plugin
documentation and the [File Processing] guide.

### On-the-fly processing

On-the-fly processing is provided by the
[`derivation_endpoint`][derivation_endpoint plugin] plugin. To set it up, we
configure the plugin with a secret key and a path prefix, [mount][Mounting
Endpoints] its Rack app in our routes on the configured path prefix, and define
processing we want to perform:

```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
```rb
# config/initializers/shrine.rb (Rails)
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
```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount Shrine.derivation_endpoint => "/derivations"
end
```

Now we can generate URLs from attached files that will perform the desired
processing:

```rb
photo.image.derivation_url(:thumbnail, 600, 400)
#=> "/derivations/thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

The on-the-fly processing feature is highly customizable, see the
[`derivation_endpoint`][derivation_endpoint plugin] plugin documentation for
more details.

## Validation

The [`validation`][validation plugin] plugin allows performing validation for
attached files. For common validations, the
[`validation_helpers`][validation_helpers plugin] plugin provides useful
validators for built in metadata:

```rb
Shrine.plugin :validation_helpers
```
```rb
class DocumentUploader < Shrine
  Attacher.validate do
    validate_max_size 5*1024*1024, message: "is too large (max is 5 MB)"
    validate_mime_type %w[application/pdf]
  end
end
```

```rb
user = User.new
user.cv = File.open("cv.pdf", "rb")
user.valid? #=> false
user.errors.to_hash #=> {:cv=>["is too large (max is 5 MB)"]}
```

For more details, see the [File Validation] guide and
[`validation_helpers`][validation_helpers plugin] plugin docs.

## Location

Shrine automatically generated random locations before uploading files. By
default the hierarchy is flat, meaning all files are stored in the root
directory of the storage.

```
024d9fe83bf4fafb.jpg
768a336bf54de219.jpg
adfaa363629f7fc5.png
...
```

The [`pretty_location`][pretty_location plugin] plugin provides a good default
hierarchy:

```rb
Shrine.plugin :pretty_location
```
```
user/
  564/
    avatar/
      aa3e0cd715.jpg
      thumb-493g82jf23.jpg
photo/
  123/
    image/
      13f8a7bc18.png
      thumb-9be62da67e.png
...
```

Buy you can also override `Shrine#generate_location` with a custom
implementation:

```rb
class ImageUploader < Shrine
  def generate_location(io, record: nil, derivative: nil, **)
    return super unless record

    [ "uploads",
      record.class.table_name,
      record.id,
      "#{derivative || "original"}-#{super}" ].compact.join("/")
  end
end
```
```
uploads/
  photos/
    123/
      original-afe929b8b4.jpg
      small-ad61f25883.jpg
      medium-41b75c42bb.jpg
      large-73e67abe50.jpg
```

> There should always be a random component in the location, so that the ORM
  dirty tracking is detected properly.

The `Shrine#generate_location` method contains a lot of useful context for the
upcoming upload:

```rb
class ImageUploader < Shrine
  def generate_location(io, record: nil, name: nil, derivative: nil, metadata: {}, **)
    storage_key #=> :cache, :store, ...
    io          #=> #<File>, #<Shrine::UploadedFile>, ...
    record      #=> #<Photo>, #<User>, ...
    name        #=> :image, :avatar, ...
    derivative  #=> :small, :medium, :large, ... (derivatives plugin)
    metadata    #=> { "filename" => "nature.jpg", "mime_type" => "image/jpeg", "size" => 18573, ... }

    # ...
  end
end
```

## Direct uploads

To improve the user experience, it's recommended to upload files asynchronously
as soon as the user selects them. The direct uploads would go to temporary
storage, just like in the synchronous flow. Then, instead of attaching a raw
file to your model, you assign the cached file JSON data.

```rb
# in the regular synchronous flow
photo.image = file

# in the direct upload flow
photo.image = '{"id":"...","storage":"cache","metadata":{...}}'
```

On the client side it's highly recommended to use **[Uppy]**, a very flexible
modern JavaScript file upload library that happens to integrate nicely with
Shrine.

### Simple direct upload

The simplest approach is to upload directly to an endpoint in your app, which
forwards uploads to the specified storage. The
[`upload_endpoint`][upload_endpoint plugin] Shrine plugin provides a
[mountable][Mounting Endpoints] Rack app that implements this endpoint:

```rb
Shrine.plugin :upload_endpoint
```
```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount Shrine.upload_endpoint(:cache) => "/upload" # POST /upload
end
```

Then you can configure Uppy's [XHR Upload][uppy xhr-upload] plugin to upload to
this endpoint. See [this walkthrough][Adding Direct App Uploads] for adding
simple direct uploads from scratch, it includes a complete JavaScript example
(there is also the [Roda][roda demo] / [Rails][rails demo] demo app).

### Presigned direct upload

For better performance, you can also upload files directly to your cloud
storage service (AWS S3, Google Cloud Storage etc). For this, your temporary
storage needs to be your cloud service:

```rb
require "shrine/storage/s3"

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(**s3_options)
}
```

In this flow, the client needs to first fetch upload parameters from the
server, and then use these parameters for the upload to the cloud service.
The [`presign_endpoint`][presign_endpoint plugin] Shrine plugin provides a
[mountable][Mounting Endpoints] Rack app that generates upload parameters:

```rb
Shrine.plugin :presign_endpoint
```
```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount Shrine.presign_endpoint(:cache) => "/s3/params" # GET /s3/params
end
```

Then you can configure Uppy's [AWS S3][uppy aws-s3] plugin to fetch params from
your endpoint before uploading to S3. See [this walkthrough][Adding Direct S3
Uploads] for adding direct uploads to S3 from scratch, it includes a complete
JavaScript example (there is also the [Roda][roda demo] / [Rails][rails demo]
demo). See also the [Direct Uploads to S3] guide for more details.

### Resumable direct upload

If your app is accepting large uploads, you can improve resilience by making
the uploads **resumable**. This can significantly improve experience for users
on slow and flaky internet connections.

#### Uppy S3 Multipart

You can achieve resumable uploads directly to S3 with the [AWS S3
Multipart][uppy aws-s3-multipart] Uppy plugin, accompanied with
`uppy_s3_multipart` Shrine plugin provided by the [uppy-s3_multipart] gem.

```rb
# Gemfile
gem "uppy-s3_multipart", "~> 0.3"
```
```rb
Shrine.plugin :uppy_s3_multipart
```
```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount Shrine.uppy_s3_multipart(:cache) => "/s3/multipart"
end
```

See the [uppy-s3_multipart] docs for more details.

#### Tus protocol

If you want a more generic approach, you can build your resumable uploads on
**[tus]** – an open resumable upload protocol. On the server side you can use
the [tus-ruby-server] gem, on the client side Uppy's [Tus][uppy tus] plugin,
and the [shrine-tus] gem for the glue.

```rb
# Gemfile
gem "tus-server", "~> 2.0"
gem "shrine-tus", "~> 2.1"
```
```rb
require "shrine/storage/tus"

Shrine.storages = {
  cache: Shrine::Storage::Tus.new, # tus server acts as temporary storage
  store: ...,                      # your permanent storage
}
```
```rb
# config/routes.rb (Rails)
Rails.application.routes.draw do
  # ...
  mount Tus::Server => "/files"
end
```

See [this walkthrough][Adding Resumable Uploads] for adding tus-powered
resumable uploads from scratch, it includes a complete JavaScript example
(there is also a [demo app][resumable demo]). See also [shrine-tus] and
[tus-ruby-server] docs for more details.

## Backgrounding

The [`backgrounding`][backgrounding plugin] allows you to move file promotion
and deletion into a background job, using the backgrounding library [of your
choice][Backgrounding Libraries]:

```rb
Shrine.plugin :backgrounding
Shrine::Attacher.promote_block do
  PromoteJob.perform_async(self.class.name, record.class.name, record.id, name, file_data)
end
Shrine::Attacher.destroy_block do
  DestroyJob.perform_async(self.class.name, data)
end
```
```rb
class PromoteJob
  include Sidekiq::Worker

  def perform(attacher_class, record_class, record_id, name, file_data)
    attacher_class = Object.const_get(attacher_class)
    record         = Object.const_get(record_class).find(record_id) # if using Active Record

    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or the record has been deleted, nothing to do
  end
end
```
```rb
class DestroyJob
  include Sidekiq::Worker

  def perform(attacher_class, data)
    attacher_class = Object.const_get(attacher_class)

    attacher = attacher_class.from_data(data)
    attacher.destroy
  end
end
```

## Clearing cache

Shrine doesn't automatically delete files uploaded to temporary storage, instead
you should set up a separate recurring task that will automatically delete old
cached files.

Most Shrine storage classes come with a `#clear!` method, which you can call in
a recurring script. For FileSystem and S3 storage it would look like this:

```rb
# FileSystem storage
file_system = Shrine.storages[:cache]
file_system.clear! { |path| path.mtime < Time.now - 7*24*60*60 } # delete files older than 1 week
```
```rb
# S3 storage
s3 = Shrine.storages[:cache]
s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 } # delete files older than 1 week
```

For S3, it may be easier and cheaper to use [S3 bucket lifecycle expiration rules](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html)  instead.

## Logging

The [`instrumentation`][instrumentation plugin] plugin sends and logs events for
important operations:

```rb
Shrine.plugin :instrumentation, notifications: ActiveSupport::Notifications

uploaded_file = Shrine.upload(io, :store)
uploaded_file.exists?
uploaded_file.download
uploaded_file.delete
```
```
Metadata (32ms) – {:storage=>:store, :io=>StringIO, :uploader=>Shrine}
Upload (1523ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :io=>StringIO, :upload_options=>{}, :uploader=>Shrine}
Exists (755ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :uploader=>Shrine}
Download (1002ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :download_options=>{}, :uploader=>Shrine}
Delete (700ms) – {:storage=>:store, :location=>"ed0e30ddec8b97813f2c1f4cfd1700b4", :uploader=>Shrine}
```

Some plugins add their own instrumentation as well when they detect that the
`instrumentation` plugin has been loaded. For that to work, the
`instrumentation` plugin needs to be loaded *before* any of these plugins.

| Plugin                | Instrumentation                         |
| :-----                | :--------------                         |
| `derivation_endpoint` | instruments file processing             |
| `derivatives`         | instruments file processing             |
| `determine_mime_type` | instruments analyzing MIME type         |
| `store_dimensions`    | instruments extracting image dimensions |
| `signature`           | instruments calculating signature       |
| `infer_extension`     | instruments inferring extension         |
| `remote_url`          | instruments remote URL downloading      |
| `data_uri`            | instruments data URI parsing            |

For instrumentation, warnings, and other logging, Shrine uses its internal
logger. You can tell Shrine to use a different logger. For example, if you're
using Rails, you might want to tell it to use the Rails logger:

```rb
Shrine.logger = Rails.logger
```

In tests you might want to tell Shrine to log only warnings:

```rb
Shrine.logger.level = Logger::WARN
```

[Creating Plugins]: https://shrinerb.com/docs/creating-plugins
[Creating Storages]: https://shrinerb.com/docs/creating-storages
[Direct Uploads to S3]: https://shrinerb.com/docs/direct-s3
[Extracting Metadata]: https://shrinerb.com/docs/metadata
[File Processing]: https://shrinerb.com/docs/processing
[File Validation]: https://shrinerb.com/docs/validation
[Retrieving Uploads]: https://shrinerb.com/docs/retrieving-uploads
[Using Attacher]: https://shrinerb.com/docs/attacher
[FileSystem]: https://shrinerb.com/docs/storage/file-system
[S3]: https://shrinerb.com/docs/storage/s3
[Memory]: https://shrinerb.com/docs/storage/memory
[Testing with Shrine]: https://shrinerb.com/docs/testing
[`Shrine::UploadedFile`]: https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html

[attacher]: #attacher
[attachment]: #attaching
[direct uploads]: #direct-uploads
[io abstraction]: #io-abstraction
[location]: #location
[metadata]: #metadata
[presigned upload]: #presigned-direct-upload
[storage]: #storage
[uploaded file]: #uploaded-file

[Adding Direct App Uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-App-Uploads
[Adding Resumable Uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Resumable-Uploads
[Adding Direct S3 Uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-S3-Uploads
[Backgrounding Libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
[Mounting Endpoints]: https://github.com/shrinerb/shrine/wiki/Mounting-Endpoints

[AWS S3]: https://aws.amazon.com/s3/
[MinIO]: https://min.io/
[DigitalOcean Spaces]: https://www.digitalocean.com/products/spaces/
[Cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[GCS]: https://github.com/renchap/shrine-google_cloud_storage
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[tus-ruby-server]: https://github.com/janko/tus-ruby-server

[Uppy]: https://uppy.io
[shrine-tus]: https://github.com/shrinerb/shrine-tus
[tus]: https://tus.io
[uppy aws-s3-multipart]: https://uppy.io/docs/aws-s3-multipart/
[uppy aws-s3]: https://uppy.io/docs/aws-s3/
[uppy tus]: https://uppy.io/docs/tus/
[uppy xhr-upload]: https://uppy.io/docs/xhr-upload/

[ImageProcessing]: https://github.com/janko/image_processing
[ImageProcessing::MiniMagick]: https://github.com/janko/image_processing/blob/master/doc/minimagick.md#readme
[ImageProcessing::Vips]: https://github.com/janko/image_processing/blob/master/doc/vips.md#readme
[`file`]: http://linux.die.net/man/1/file
[Down]: https://github.com/janko/down

[activerecord plugin]: https://shrinerb.com/docs/plugins/activerecord
[add_metadata plugin]: https://shrinerb.com/docs/plugins/add_metadata
[backgrounding plugin]: https://shrinerb.com/docs/plugins/backgrounding
[data_uri plugin]: https://shrinerb.com/docs/plugins/data_uri
[derivation_endpoint plugin]: https://shrinerb.com/docs/plugins/derivation_endpoint
[derivatives plugin]: https://shrinerb.com/docs/plugins/derivatives
[determine_mime_type plugin]: https://shrinerb.com/docs/plugins/determine_mime_type
[instrumentation plugin]: https://shrinerb.com/docs/plugins/instrumentation
[hanami plugin]: https://github.com/katafrakt/hanami-shrine
[model plugin]: https://shrinerb.com/docs/plugins/model
[entity plugin]: https://shrinerb.com/docs/plugins/entity
[mongoid plugin]: https://github.com/shrinerb/shrine-mongoid
[presign_endpoint plugin]: https://shrinerb.com/docs/plugins/presign_endpoint
[pretty_location plugin]: https://shrinerb.com/docs/plugins/pretty_location
[rack_file plugin]: https://shrinerb.com/docs/plugins/rack_file
[rom plugin]: https://github.com/shrinerb/shrine-rom
[sequel plugin]: https://shrinerb.com/docs/plugins/sequel
[signature plugin]: https://shrinerb.com/docs/plugins/signature
[store_dimensions plugin]: https://shrinerb.com/docs/plugins/store_dimensions
[upload_endpoint plugin]: https://shrinerb.com/docs/plugins/upload_endpoint
[validation_helpers plugin]: https://shrinerb.com/docs/plugins/validation_helpers
[validation plugin]: https://shrinerb.com/docs/plugins/validation

[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[roda demo]: https://github.com/shrinerb/shrine/tree/master/demo
[resumable demo]: https://github.com/shrinerb/shrine-tus-demo

[`#read`]: https://ruby-doc.org/core/IO.html#method-i-read
[`#eof?`]: https://ruby-doc.org/core/IO.html#method-i-eof
[`#rewind`]: https://ruby-doc.org/core/IO.html#method-i-rewind
[`#close`]: https://ruby-doc.org/core/IO.html#method-i-close
[`IO`]: https://ruby-doc.org/core/IO.html

[storages]: https://shrinerb.com/docs/external/extensions#storages
[plugins]: https://shrinerb.com/plugins
[external plugins]: https://shrinerb.com/docs/external/extensions#plugins
