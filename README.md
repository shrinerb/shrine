# [Shrine]

Shrine is a toolkit for file attachments in Ruby applications. Some highlights:

* **Modular design** – the [plugin system] allows you to load only the functionality you need
* **Memory friendly** – streaming uploads and [downloads][Retrieving Uploads] make it work great with large files
* **Cloud storage** – store files on [disk][FileSystem], [AWS S3][S3], [Google Cloud][GCS], [Cloudinary] and [others][external]
* **Persistence integrations** – works with [Sequel][sequel plugin], [ActiveRecord][activerecord plugin], [ROM][rom plugin], [Hanami::Model][hanami plugin] and [Mongoid][mongoid plugin]
* **Flexible processing** – generate thumbnails [up front] or [on-the-fly] using [ImageMagick][ImageProcessing::MiniMagick] or [libvips][ImageProcessing::Vips]
* **Metadata validation** – [validate files][validation] based on [extracted metadata][metadata]
* **Direct uploads** – upload asynchronously [to your app][simple upload] or [to the cloud][presigned upload] using [Uppy]
* **Resumable uploads** – make large file uploads [resumable][resumable upload] on [S3][uppy-s3_multipart] or [tus][tus-ruby-server]
* **Background jobs** – built-in support for [background processing][backgrounding] that supports [any backgrounding library][Backgrounding Libraries]

If you're curious how it compares to other file attachment libraries, see the [Advantages of Shrine].

## Resources

| Resource          | URL                                                                            |
| :---------------- | :----------------------------------------------------------------------------- |
| Website           | [shrinerb.com](https://shrinerb.com)                                           |
| Demo code         | [Roda][roda demo] / [Rails][rails demo]                                        |
| Source            | [github.com/shrinerb/shrine](https://github.com/shrinerb/shrine)               |
| Wiki              | [github.com/shrinerb/shrine/wiki](https://github.com/shrinerb/shrine/wiki)     |
| Bugs              | [github.com/shrinerb/shrine/issues](https://github.com/shrinerb/shrine/issues) |
| Help & Discussion | [discourse.shrinerb.com](https://discourse.shrinerb.com)                       |

## Contents

* [Quick start](#quick-start)
* [Storage](#storage)
* [Uploader](#uploader)
  - [Uploading](#uploading)
  - [IO abstraction](#io-abstraction)
* [Uploaded file](#uploaded-file)
* [Attachment](#attachment)
* [Attacher](#attacher)
* [Plugin system](#plugin-system)
* [Metadata](#metadata)
  * [MIME type](#mime-type)
  * [Other metadata](#other-metadata)
* [Processing](#processing)
  * [Processing up front](#processing-up-front)
  * [Processing on-the-fly](#processing-on-the-fly)
* [Validation](#validation)
* [Location](#location)
* [Direct uploads](#direct-uploads)
  - [Simple direct upload](#simple-direct-upload)
  - [Presigned direct upload](#presigned-direct-upload)
  - [Resumable direct upload](#resumable-direct-upload)
* [Backgrounding](#backgrounding)
* [Clearing cache](#clearing-cache)
* [Logging](#logging)

## Quick start

Add Shrine to the Gemfile and write an initializer which sets up the storage and
loads the ORM plugin:

```rb
# Gemfile
gem "shrine", "~> 2.0"
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

```rb
Sequel.migration do
  change do
    add_column :photos, :image_data, :text # or :jsonb
  end
end
```

In Rails with Active Record the migration would look similar:

```sh
$ rails generate migration add_image_data_to_photos image_data:text
```
```rb
class AddImageDataToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :image_data, :text # or :jsonb
  end
end
```

Now you can create an uploader class for the type of files you want to upload,
and add a virtual attribute for handling attachments using this uploader to
your model. If you do not care about adding plugins or additional processing,
you can use `Shrine::Attachment`.

```rb
class ImageUploader < Shrine
  # plugins and uploading logic
end
```

```rb
class Photo < Sequel::Model # ActiveRecord::Base
  include ImageUploader::Attachment(:image) # adds an `image` virtual attribute
end
```

Let's now add the form fields which will use this virtual attribute (NOT the
`<attachment>_data` column attribute). We need (1) a file field for choosing
files, and (2) a hidden field for retaining the uploaded file in case of
validation errors and for potential [direct uploads].

```rb
# with Rails form builder:
form_for @photo do |f|
  f.hidden_field :image, value: @photo.cached_image_data
  f.file_field :image
  f.submit
end
```
```rb
# with Simple Form:
simple_form_for @photo do |f|
  f.input :image, as: :hidden, input_html: { value: @photo.cached_image_data }
  f.input :image, as: :file
  f.button :submit
end
```
```rb
# with Forme:
form @photo, action: "/photos", enctype: "multipart/form-data" do |f|
  f.input :image, type: :hidden, value: @photo.cached_image_data
  f.input :image, type: :file
  f.button "Create"
end
```

Note that the file field needs to go *after* the hidden field, so that
selecting a new file can always override the cached file in the hidden field.
Also notice the `enctype="multipart/form-data"` HTML attribute, which is
required for submitting files through the form (the Rails form builder
will automatically generate this for you).

When the form is submitted, in your router/controller you can assign the file
from request params to the attachment attribute on the model.

```rb
# In Rails:
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
```rb
# In Sinatra:
post "/photos" do
  Photo.create(params[:photo])
  # ...
end
```

Once a file is uploaded and attached to the record, you can retrieve a URL to
the uploaded file with `#<attachment>_url` and display it on the page:

```erb
<!-- In Rails: -->
<%= image_tag @photo.image_url %>
```
```erb
<!-- In HTML: -->
<img src="<%= @photo.image_url %>" />
```

## Storage

A "storage" in Shrine is an object that encapsulates communication with a
specific storage service, by implementing a common public interface. Storage
instances are registered under an identifier in `Shrine.storages`, so that they
can later be used by [uploaders][uploader].

Previously we've shown the [FileSystem] storage which saves files to disk, but
Shrine also ships with [S3] storage which stores files on [AWS S3] (or any
S3-compatible service such as [DigitalOcean Spaces] or [MinIO]).

```rb
# Gemfile
gem "aws-sdk-s3", "~> 1.14" # for AWS S3 storage
```
```rb
require "shrine/storage/s3"

s3_options = {
  bucket:            "<YOUR BUCKET>", # required
  access_key_id:     "<YOUR ACCESS KEY ID>",
  secret_access_key: "<YOUR SECRET ACCESS KEY>",
  region:            "<YOUR REGION>",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(**s3_options),
}
```

The above example sets up S3 for both temporary and permanent storage, which is
suitable for [direct uploads][Direct Uploads to S3]. The `:cache` and
`:store` names are special only in terms that the [attacher] will automatically
pick them up, you can also register more storage objects under different names.

See the [FileSystem] and [S3] storage docs for more details. There are [many
more Shrine storages][external] provided by external gems, and you can also
[create your own storage][Creating Storages].

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
This includes built-in IO and IO-like objects like File, Tempfile and StringIO.

When a file is uploaded to a Rails app, in request params it will be
represented by an `ActionDispatch::Http::UploadedFile` object, which is also an
IO-like object accepted by Shrine. In other Rack applications the uploaded file
will be represented as a Hash, but it can be converted into an IO-like object
with the [`rack_file`][rack_file plugin] plugin.

Here are some examples of various IO-like objects that can be uploaded:

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
record [attachment]. It contains the following information:

| Key        | Description                                        |
| :-------   | :----------                                        |
| `id`       | location of the file on the storage                |
| `storage`  | identifier of the storage the file was uploaded to |
| `metadata` | file [metadata] that was extracted before upload   |

```rb
uploaded_file = uploader.upload(file)
uploaded_file.data #=> {"id"=>"949sdjg834.jpg","storage"=>"store","metadata"=>{...}}

uploaded_file.id       #=> "949sdjg834.jpg"
uploaded_file.storage  #=> #<Shrine::Storage::S3>
uploaded_file.metadata #=> {...}
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

## Attachment

Storage objects, uploaders, and uploaded file objects are Shrine's foundational
components. To help you actually attach uploaded files to database records in
your application, Shrine comes with a high-level attachment interface built on
top of these components.

There are plugins for hooking into most database libraries, and in case of
ActiveRecord and Sequel the plugin will automatically tie the attached files to
records' lifecycles. But you can also use Shrine just with plain old Ruby
objects.

```rb
Shrine.plugin :sequel # :activerecord
```

```rb
class Photo < Sequel::Model # ActiveRecord::Base
  include ImageUploader::Attachment.new(:image) #
  include ImageUploader::Attachment(:image)     # these are all equivalent
  include ImageUploader[:image]                 #
end
```

You can choose whichever of these syntaxes you prefer. Either of these
will create a `Shrine::Attachment` module with attachment methods for the
specified attribute, which then get added to your model when you include it:

| Method            | Description                                                                       |
| :-----            | :----------                                                                       |
| `#image=`         | uploads the file to temporary storage and serializes the result into `image_data` |
| `#image`          | returns [`Shrine::UploadedFile`][uploaded file] instantiated from `image_data`    |
| `#image_url`      | calls `url` on the attachment if it's present, otherwise returns nil              |
| `#image_attacher` | returns instance of [`Shrine::Attacher`][attacher] which handles the attaching    |

The ORM plugin that we loaded adds appropriate callbacks. For example, saving
the record uploads the attachment to permanent storage, while deleting the
record deletes the attachment.

```rb
# no file is attached
photo.image #=> nil

# the assigned file is cached to temporary storage and written to `image_data` column
photo.image = File.open("waterfall.jpg")
photo.image      #=> #<Shrine::UploadedFile @data={...}>
photo.image_url  #=> "/uploads/cache/0sdfllasfi842.jpg"
photo.image_data #=> '{"id":"0sdfllasfi842.jpg","storage":"cache","metadata":{...}}'

# the cached file is promoted to permanent storage and saved to `image_data` column
photo.save
photo.image      #=> #<Shrine::UploadedFile @data={...}>
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

## Attacher

The model attachment attributes and callbacks added by `Shrine::Attachment`
just delegate the behaviour to their underlying `Shrine::Attacher` object.

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
as a more explicit alternative to models' attachment interface, or simply when
you need something that's not available through the attachment methods.

You can do things such as change the temporary and permanent storage the
attacher uses, or upload files directly to permanent storage. See the [Using
Attacher] guide for more details.

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
[create your own plugin][Creating Plugins].

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

Shrine allows you to process attached files up front or on-the-fly. For
example, if your app is accepting image uploads, you can generate a predefined
set of of thumbnails when the image is attached to a record, or you can have
thumbnails generated dynamically as they're needed.

For image processing, it's recommended to use the **[ImageProcessing]** gem,
which is a high-level wrapper for processing with [ImageMagick] (via
[MiniMagick]) or [libvips] (via [ruby-vips]).

```sh
$ brew install imagemagick vips
```

### Processing up front

You can use the [`derivatives`][derivatives plugin] plugin to generate a set of
pre-defined processed files:

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
```rb
photo = Photo.new(image: file)
photo.image_derivatives! # calls derivatives processor and uploads results
photo.save
```

If you're allowing the attached file to be updated later on, in your update
route make sure to create derivatives for new attachments:

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

### Processing on-the-fly

On-the-fly processing is provided by the
[`derivation_endpoint`][derivation_endpoint plugin] plugin. It comes with a
[mountable][Mounting Endpoints] Rack app which applies processing on request
and returns processed files.

To set it up, we mount the Rack app in our router on a chosen path prefix,
configure the plugin with a secret key and that path prefix, and define
processing we want to perform:

```rb
# Gemfile
gem "image_processing", "~> 1.8"
```
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

Now we can generate URLs from attached files that will perform the desired
processing:

```rb
photo.image.derivation_url(:thumbnail, 600, 400)
#=> "/derivations/image/thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
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
directory of the storage. The [`pretty_location`][pretty_location plugin]
plugin provides a good default hierarchy, but you can also override
`#generate_location` with a custom implementation:

```rb
class ImageUploader < Shrine
  def generate_location(io, record: nil, derivative: nil, **)
    type  = record.class.name.downcase if record
    style = derivative ? "thumbs" : "originals"
    name  = super # the default unique identifier

    [type, style, name].compact.join("/")
  end
end
```
```
uploads/
  photos/
    originals/
      la98lda74j3g.jpg
    thumbs/
      95kd8kafg80a.jpg
      ka8agiaf9gk4.jpg
```

Note that there should always be a random component in the location, so that
the ORM dirty tracking is detected properly. Inside `#generate_location` you
can also access the extracted metadata through the `:metadata` option.

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

On the client side it's highly recommended to use **[Uppy]** :dog:, a very
flexible modern JavaScript file upload library that happens to integrate nicely
with Shrine.

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
  mount ImageUploader.upload_endpoint(:cache) => "/images/upload" # POST /images/upload
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
gem "shrine-tus", "~> 1.2"
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
Shrine::Attacher.promote_block { PromoteJob.perform_later(self.class, record, name, file_data) }
Shrine::Attacher.destroy_block { DestroyJob.perform_later(self.class, data) }
```
```rb
class PromoteJob < ActiveJob::Base
  def perform(attacher_class, record, name, file_data)
    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged, ActiveRecord::RecordNotFound
    # attachment has changed or the record has been deleted, nothing to do
  end
end
```
```rb
class DestroyJob < ActiveJob::Base
  def perform(attacher_class, data)
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

## Code of Conduct

Everyone interacting in the Shrine project’s codebases, issue trackers, and
mailing lists is expected to follow the [Shrine code of conduct][CoC].

## License

The gem is available as open source under the terms of the [MIT License].

<!-- Guides & RDocs -->
[Advantages of Shrine]: /doc/advantages.md#readme
[Creating Plugins]: /doc/creating_plugins.md#readme
[Creating Storages]: /doc/creating_storages.md#readme
[Direct Uploads to S3]: /doc/direct_s3.md#readme
[Extracting Metadata]: /doc/metadata.md#readme
[File Processing]: /doc/processing.md#readme
[File Validation]: /doc/validation.md#readme
[Retrieving Uploads]: /doc/retrieving_uploads.md#readme
[Using Attacher]: /doc/attacher.md#readme
[FileSystem]: /doc/storage/file_system.md#readme
[S3]: /doc/storage/s3.md#readme
[`Shrine::UploadedFile`]: https://shrinerb.com/rdoc/classes/Shrine/UploadedFile/InstanceMethods.html

<!-- Sections -->
[attacher]: #attacher
[attachment]: #attachment
[backgrounding]: #backgrounding
[direct uploads]: #direct-uploads
[io abstraction]: #io-abstraction
[location]: #location
[metadata]: #metadata
[up front]: #processing-up-front
[on-the-fly]: #processing-on-the-fly
[plugin system]: #plugin-system
[simple upload]: #simple-direct-upload
[presigned upload]: #presigned-direct-upload
[resumable upload]: #resumable-direct-upload
[storage]: #storage
[uploaded file]: #uploaded-file
[uploading]: #uploading
[uploader]: #uploader
[validation]: #validation

<!-- Wikis -->
[Adding Direct App Uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-App-Uploads
[Adding Resumable Uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Resumable-Uploads
[Adding Direct S3 Uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-S3-Uploads
[Backgrounding Libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-Libraries
[Mounting Endpoints]: https://github.com/shrinerb/shrine/wiki/Mounting-Endpoints

<!-- Storage & Destinations -->
[AWS S3]: https://aws.amazon.com/s3/
[MinIO]: https://min.io/
[DigitalOcean Spaces]: https://www.digitalocean.com/products/spaces/
[Cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[GCS]: https://github.com/renchap/shrine-google_cloud_storage
[uppy-s3_multipart]: https://github.com/janko/uppy-s3_multipart
[tus-ruby-server]: https://github.com/janko/tus-ruby-server

<!-- Direct Uploads -->
[Uppy]: https://uppy.io
[shrine-tus]: https://github.com/shrinerb/shrine-tus
[tus]: https://tus.io
[uppy aws-s3-multipart]: https://uppy.io/docs/aws-s3-multipart/
[uppy aws-s3]: https://uppy.io/docs/aws-s3/
[uppy tus]: https://uppy.io/docs/tus/
[uppy xhr-upload]: https://uppy.io/docs/xhr-upload/

<!-- Processing -->
[ImageMagick]: https://imagemagick.org/
[MiniMagick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/libvips/ruby-vips
[ImageProcessing]: https://github.com/janko/image_processing
[ImageProcessing::MiniMagick]: https://github.com/janko/image_processing/blob/master/doc/minimagick.md#readme
[ImageProcessing::Vips]: https://github.com/janko/image_processing/blob/master/doc/vips.md#readme
[libvips]: http://libvips.github.io/libvips/
[`file`]: http://linux.die.net/man/1/file

<!-- Plugins -->
[activerecord plugin]: /doc/plugins/activerecord.md#readme
[add_metadata plugin]: /doc/plugins/add_metadata.md#readme
[backgrounding plugin]: /doc/plugins/backgrounding.md#readme
[derivation_endpoint plugin]: /doc/plugins/derivation_endpoint.md#readme
[derivatives plugin]: /doc/plugins/derivatives.md#readme
[determine_mime_type plugin]: /doc/plugins/determine_mime_type.md#readme
[instrumentation plugin]: /doc/plugins/instrumentation.md#readme
[hanami plugin]: https://github.com/katafrakt/hanami-shrine
[mongoid plugin]: https://github.com/shrinerb/shrine-mongoid
[presign_endpoint plugin]: /doc/plugins/presign_endpoint.md#readme
[pretty_location plugin]: /doc/plugins/pretty_location.md#readme
[rack_file plugin]: /doc/plugins/rack_file.md#readme
[rom plugin]: https://github.com/shrinerb/shrine-rom
[sequel plugin]: /doc/plugins/sequel.md#readme
[signature plugin]: /doc/plugins/signature.md#readme
[store_dimensions plugin]: /doc/plugins/store_dimensions.md#readme
[upload_endpoint plugin]: /doc/plugins/upload_endpoint.md#readme
[validation_helpers plugin]: /doc/plugins/validation_helpers.md#readme
[validation plugin]: /doc/plugins/validation.md#readme

<!-- Demos -->
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[roda demo]: https://github.com/shrinerb/shrine/tree/master/demo
[resumable demo]: https://github.com/shrinerb/shrine-tus-demo

<!-- Misc -->
[`#read`]: https://ruby-doc.org/core/IO.html#method-i-read
[`#eof?`]: https://ruby-doc.org/core/IO.html#method-i-eof
[`#rewind`]: https://ruby-doc.org/core/IO.html#method-i-rewind
[`#close`]: https://ruby-doc.org/core/IO.html#method-i-close
[`IO`]: https://ruby-doc.org/core/IO.html
[Refile]: https://github.com/refile/refile
[Roda]: https://github.com/jeremyevans/roda

<!-- Project -->
[Shrine]: https://shrinerb.com
[external]: https://shrinerb.com/#external
[plugins]: https://shrinerb.com/#plugins
[CoC]: CODE_OF_CONDUCT.md
[MIT License]: http://opensource.org/licenses/MIT
