# [Shrine]

Shrine is a toolkit for file attachments in Ruby applications. Some highlights:

* **Modular design** – the [plugin system][plugin system] allows you to load only the functionality you need
* **Memory friendly** – streaming uploads and downloads make it work great with large files
* **Cloud storage** – store files on [disk][FileSystem], [AWS S3][S3], [Google Cloud][GCS], [Cloudinary] and others
* **ORM integrations** – works with [Sequel][sequel plugin], [ActiveRecord][activerecord plugin], [Hanami::Model][hanami plugin] and [Mongoid][mongoid plugin]
* **Flexible processing** – generate thumbnails with [ImageMagick] or [libvips] using the [ImageProcessing][image_processing] gem
* **Metadata validation** – [validate files][validation_helpers plugin] based on [extracted metadata][Extracting Metadata]
* **Direct uploads** – upload asynchronously [to your app][upload_endpoint plugin] or [to the cloud][presign_endpoint plugin] using [Uppy]
* **Resumable uploads** – make large file uploads [resumable][tus] by pointing [Uppy][uppy tus] to a [resumable endpoint][tus-ruby-server]
* **Background jobs** – built-in support for [background processing][backgrounding plugin] that supports [any backgrounding library][backgrounding libraries]

If you're curious how it compares to other file attachment libraries, see the [Advantages of Shrine].

## Resources

- Documentation: [shrinerb.com](https://shrinerb.com)
- Demo code: [Roda][roda demo] / [Rails][rails demo]
- Source: [github.com/shrinerb/shrine](https://github.com/shrinerb/shrine)
- Wiki: [github.com/shrinerb/shrine/wiki](https://github.com/shrinerb/shrine/wiki)
- Bugs: [github.com/shrinerb/shrine/issues](https://github.com/shrinerb/shrine/issues)
- Help & Discussion: [groups.google.com/group/ruby-shrine](https://groups.google.com/forum/#!forum/ruby-shrine)

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
Sequel.migration do                           # class AddImageDataToPhotos < ActiveRecord::Migration
  change do                                   #   def change
    add_column :photos, :image_data, :text    #     add_column :photos, :image_data, :text
  end                                         #   end
end                                           # end
```

Now you can create an uploader class for the type of files you want to upload,
and add a virtual attribute for handling attachments using this uploader to
your model:

```rb
class ImageUploader < Shrine
  # plugins and uploading logic
end
```

```rb
class Photo < Sequel::Model # ActiveRecord::Base
  include ImageUploader::Attachment.new(:image) # adds an `image` virtual attribute
end
```

Let's now add the form fields which will use this virtual attribute. We need
(1) a file field for choosing files, and (2) a hidden field for retaining the
uploaded file in case of validation errors and for potential [direct
uploads][direct S3 uploads guide].

```rb
# with Forme:
form @photo, action: "/photos", enctype: "multipart/form-data" do |f|
  f.input :image, type: :hidden, value: @photo.cached_image_data
  f.input :image, type: :file
  f.button "Create"
end

# with Rails form builder:
form_for @photo do |f|
  f.hidden_field :image, value: @photo.cached_image_data
  f.file_field :image
  f.submit
end

# with Simple Form:
simple_form_for @photo do |f|
  f.input :image, as: :hidden, input_html: { value: @photo.cached_image_data }
  f.input :image, as: :file
  f.button :submit
end
```

Note that the file field needs to go *after* the hidden field, so that
selecting a new file can always override the cached file in the hidden field.
Also notice the `enctype="multipart/form-data"` HTML attribute, which is
required for submitting files through the form; the Rails form builder
will automatically generate this for you.

Now in your router/controller the attachment request parameter can be assigned
to the model like any other attribute:

```rb
post "/photos" do
  Photo.create(params[:photo])
  # ...
end
```

Once a file is uploaded and attached to the record, you can retrieve a URL to
the uploaded file with `#<attachment>_url` and display it on the page:

```rb
image_tag @photo.image_url
```

## Storage

A "storage" in Shrine is an object responsible for managing files on a specific
storage service (disk, AWS S3, Google Cloud etc), which implements a generic
method interface. Storages are configured directly and registered under a name
in `Shrine.storages`, so that they can later be used by uploaders.

```rb
# Gemfile
gem "aws-sdk-s3", "~> 1.2" # for AWS S3 storage
```
```rb
require "shrine/storage/s3"

s3_options = {
  bucket:            "my-bucket", # required
  access_key_id:     "abc",
  secret_access_key: "xyz",
  region:            "my-region",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(**s3_options),
}
```

The above example sets up AWS S3 storage both for temporary and permanent
storage, which is suitable for [direct uploads][direct S3 uploads guide]. The
`:cache` and `:store` names are special only in terms that the attacher will
automatically pick them up, but you can also register more storages under
different names.

Shrine ships with [FileSystem] and [S3] storage, take a look at their
documentation for more details on various features they support. There are
[many more Shrine storages][external storages] provided by external gems, and
you can also [create your own storage][creating storage].

## Uploader

Uploaders are subclasses of `Shrine`, and are essentially wrappers around
storages. They perform common tasks around upload that aren't related to a
particular storage.

```rb
class ImageUploader < Shrine
  # image attachent logic
end
```
```rb
uploader = ImageUploader.new(:store)
uploader #=> uploader for storage registered under `:store`
```

It's common to create an uploader for each type of file that you want to handle
(image, video, audio, document etc), but really you can organize them in any way
you like.

### Uploading

The main method of the uploader is `#upload`, which takes an IO-like object on
the input, and returns a representation of the uploaded file on the output.

```rb
uploaded_file = uploader.upload(file)
uploaded_file #=> #<Shrine::UploadedFile>
```

Some of the tasks performed by `#upload` include:

* file processing (if defined)
* extracting metadata
* generating location
* uploading (this is where the storage is called)
* closing the uploaded file

Additional upload options can be passed via `:upload_options`, and they will be
forwarded directly to `Storage#upload` (see the documentation of your storage
for the list of available options):

```rb
uploader.upload(file, upload_options: { acl: "public-read" })
```

### IO abstraction

Shrine is able to upload any IO-like object that responds to `#read`,
`#rewind`, `#eof?` and `#close`. This includes built-in IO and IO-like objects
like File, Tempfile and StringIO.

When a file is uploaded to a Rails app, it will be represented by an
ActionDispatch::Http::UploadedFile object in the params. This is also an
IO-like object accepted by Shrine. In other Rack applications the uploaded file
will be represented as a Hash, but it can still be attached when `rack_file`
plugin is loaded.

Here are some examples of IO objects that can be uploaded:

```rb
uploader.upload File.open("/path/to/file", "rb")             # upload from disk
uploader.upload StringIO.new("file content")                 # upload from memory
uploader.upload ActionDispatch::Http::UploadedFile.new       # upload from Rails controller
uploader.upload Shrine.rack_file({ tempfile: Tempfile.new }) # upload from Rack controller
uploader.upload Rack::Test::UploadedFile.new                 # upload from rack-test
uploader.upload Down.open("https://example.org/file")        # upload from internet
```

`Shrine::UploadedFile`, the object returned after upload, is itself an IO-like
object as well. This makes it trivial to reupload a file from one storage to
another, and this is used by the attacher to reupload a file stored on
temporary storage to permanent storage.

## Uploaded file

The `Shrine::UploadedFile` object represents the file that was uploaded to the
storage, and it's what's returned from `Shrine#upload` or when retrieving a
record attachment. It contains the following information:

* `storage` – identifier of the storage the file was uploaded to
* `id` – location of the file on the storage
* `metadata` – file metadata that was extracted before upload

```rb
uploaded_file = uploader.upload(file)

uploaded_file.id       #=> "949sdjg834.jpg"
uploaded_file.storage  #=> #<Shrine::Storage::FileSystem>
uploaded_file.metadata #=> {...}

# It can be serialized into JSON and saved to a database column
uploaded_file.to_json  #=> '{"id":"949sdjg834.jpg","storage":"store","metadata":{...}}'
```

It comes with many convenient methods that delegate to the storage:

```rb
uploaded_file.url                 #=> "https://my-bucket.s3.amazonaws.com/949sdjg834.jpg"
uploaded_file.open                # opens the uploaded file
uploaded_file.download            #=> #<File:/var/folders/.../20180302-33119-1h1vjbq.jpg>
uploaded_file.stream(destination) # streams uploaded content into a writable destination
uploaded_file.exists?             #=> true
uploaded_file.delete              # deletes the file from the storage

# open/download the uploaded file for the duration of the block
uploaded_file.open     { |io| io.read }
uploaded_file.download { |tempfile| tempfile.read }
```

It also implements the IO-like interface that conforms to Shrine's IO
abstraction, which allows it to be uploaded again to other storages.

```rb
uploaded_file.read   # returns content of the uploaded file
uploaded_file.eof?   # returns true if the whole IO was read
uploaded_file.rewind # rewinds the IO
uploaded_file.close  # closes the IO
```

If you want to retrieve the content of the uploaded file, you can use a
combination of `#open` and `#read`:

```rb
uploaded_file.open(&:read) #=> "..." (binary content of the uploaded file)
```

## Attachment

Storages, uploaders, and uploaded file objects are the main components for
managing files. Since most often you also want to *attach* the uploaded files
to database records, Shrine comes with a high-level attachment interface, which
uses these components internally.

Usually you're using an ORM for saving database records, in which case you can
load an additional plugin to automatically tie the attached files to record
lifecycle. But you can also use Shrine just with plain models.

```rb
Shrine.plugin :sequel # :activerecord
```

```rb
class Photo < Sequel::Model # ActiveRecord::Base
  include ImageUploader::Attachment.new(:image) #
  include ImageUploader.attachment(:image)      # these are all equivalent
  include ImageUploader[:image]                 #
end
```

You can choose whichever of these three syntaxes you prefer. Either of these
will create a `Shrine::Attachment` module with attachment methods for the
specified attribute, which then get added to your model when you include it:

* `#image=` – uploads the file to temporary storage and serializes the result into `image_data`
* `#image` – returns `Shrine::UploadedFile` instantiated from `image_data`
* `#image_url` – calls `url` on the attachment if it's present, otherwise returns nil
* `#image_attacher` – returns instance of `Shrine::Attacher` which handles the attaching

The ORM plugin that we loaded adds appropriate callbacks, so when record is
saved the attachment is uploaded to permanent storage, and when record is
deleted the attachment is deleted as well.

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
# or
photo.update(image: nil)      # removes the attachment and deletes previous
```

In addition to assigning raw files, you can also assign a JSON representation
of files that are already uploaded to the temporary storage. This allows Shrine
to retain cached files in case of validation errors and handle [direct uploads]
via the hidden form field.

```rb
photo.image = '{"id":"9260ea09d8effd.jpg","storage":"cache","metadata":{...}}'
```

## Attacher

The model attachment attributes and callbacks just delegate the behaviour
to their underlying `Shrine::Attacher` object.

```rb
photo.image_attacher #=> #<Shrine::Attacher>
```

The `Shrine::Attacher` object can be instantiated and used directly:

```rb
attacher = ImageUploader::Attacher.new(photo, :image)

attacher.assign(file) # equivalent to `photo.image = file`
attacher.get          # equivalent to `photo.image`
attacher.url          # equivalent to `photo.image_url`
```

The attacher is what drives attaching files to model instances, and it functions
independently from models' attachment interface. This means that you can use it
as an alternative, in case you prefer not to add additional attributes to the
model, or prefer explicitness over callbacks. It's also useful when you need
something more advanced which isn't available through the attachment
attributes.

The `Shrine::Attacher` by default uses `:cache` for temporary and `:store` for
permanent storage, but you can specify a different storage:

```rb
ImageUploader::Attacher.new(photo, :image, cache: :other_cache, store: :other_store)

# OR

photo.image_attacher(cache: :other_cache, store: :other_store)
photo.image = file # uploads to :other_cache storage
photo.save         # promotes to :other_store storage
```

You can also skip the temporary storage altogether and upload files directly to
the primary storage:

```rb
uploaded_file = attacher.store!(file) # upload file directly to permanent storage
attacher.set(uploaded_file)           # attach the uploaded file
```

Whenever the attacher uploads or deletes files, it sends a `context` hash
which includes `:record`, `:name`, and `:action` keys, so that you can perform
processing or generate location differently depending on this information. See
"Context" section for more details.

For more information about `Shrine::Attacher`, see the [Using Attacher] guide.

## Plugin system

By default Shrine comes with a small core which provides only the essential
functionality. All additional features are available via [plugins], which also
ship with Shrine. This way you can choose exactly what and how much Shrine does
for you, and you load the code only for features that you use.

```rb
Shrine.plugin :logging # adds logging
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
[create your own plugin][creating plugin].

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

By default these values are determined from the following attributes on the IO
object:

* `filename` – `io.original_filename` or `io.path`
* `mime_type` – `io.content_type`
* `size` – `io.size`

### MIME type

By default `mime_type` will be inherited from `#content_type` attribute of the
uploaded file, which is set from the `Content-Type` request header. However,
this header is determined by the browser solely based on the file extension.
This means that by default Shrine's `mime_type` is *not guaranteed* to hold
the actual MIME type of the file.

To remedy that, you can load the `determine_mime_type` plugin, which will make
Shrine extract the MIME type from *file content*.

```rb
Shrine.plugin :determine_mime_type
```
```rb
photo = Photo.create(image: StringIO.new("<?php ... ?>"))
photo.image.mime_type #=> "text/x-php"
```

By the default the UNIX [`file`] utility is used to determine the MIME type,
but you can also choose a different analyzer – see the plugin documentation for
more details.

### Other metadata

In addition to `size`, `filename`, and `mime_type`, you can also extract image
dimensions using the `store_dimensions` plugin, as well as any custom metadata
using the `add_metadata` plugin. Check out the [Extracting Metadata] guide for
more details.

Note that you can also manually override extracted metadata by passing the
`:metadata` option to `Shrine#upload`:

```rb
uploaded_file = uploader.upload(file, metadata: { "filename" => "Matrix[1999].mp4", "foo" => "bar" })
uploaded_file.original_filename #=> "Matrix[1999].mp4"
uploaded_file.metadata["foo"]   #=> "bar"
```

## Processing

Shrine's `processing` plugin allows you to intercept when the cached file is
being uploaded to permanent storage, and do any file processing your might want.

If you're uploading images, it's common to want to generate various thumbnails.
It's recommended to use the **[ImageProcessing][image_processing]** gem for
this, which provides a convenient API over [ImageMagick] and [libvips]. You
also need to load the `versions` plugin to be able to save multiple files.

```sh
$ brew install imagemagick
```
```rb
# Gemfile
gem "image_processing", "~> 1.0"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :processing # allows hooking into promoting
  plugin :versions   # enable Shrine to handle a hash of files
  plugin :delete_raw # delete processed files after uploading

  process(:store) do |io, context|
    versions = { original: io } # retain original

    io.download do |original|
      pipeline = ImageProcessing::MiniMagick.source(original)

      versions[:large]  = pipeline.resize_to_limit!(800, 800)
      versions[:medium] = pipeline.resize_to_limit!(500, 500)
      versions[:small]  = pipeline.resize_to_limit!(300, 300)
    end

    versions # return the hash of processed files
  end
end
```

After these files have been uploaded, their data will all be saved to the
`<attachment>_data` column. The attachment getter will then read them as a Hash
of `Shrine::UploadedFile` objects.

```rb
photo.image_data #=>
# '{
#   "original": {"id":"9sd84.jpg", "storage":"store", "metadata":{...}},
#   "large": {"id":"lg043.jpg", "storage":"store", "metadata":{...}},
#   "medium": {"id":"kd9fk.jpg", "storage":"store", "metadata":{...}},
#   "small": {"id":"932fl.jpg", "storage":"store", "metadata":{...}}
# }'

photo.image #=>
# {
#   :original => #<Shrine::UploadedFile @data={"id"=>"9sd84.jpg", ...}>,
#   :large    => #<Shrine::UploadedFile @data={"id"=>"lg043.jpg", ...}>,
#   :medium   => #<Shrine::UploadedFile @data={"id"=>"kd9fk.jpg", ...}>,
#   :small    => #<Shrine::UploadedFile @data={"id"=>"932fl.jpg", ...}>,
# }

photo.image[:medium]           #=> #<Shrine::UploadedFile>
photo.image[:medium].url       #=> "/uploads/store/lg043.jpg"
photo.image[:medium].size      #=> 5825949
photo.image[:medium].mime_type #=> "image/jpeg"
```

The `versions` plugin also expands `#<attachment>_url` to accept version names:

```rb
photo.image_url(:large) #=> "https://..."
```

For more details, including examples of how to do custom and on-the-fly
processing, see the [File Processing] guide.

## Context

The `#upload` (and `#delete`) methods accept a hash of options as the second
argument, which is forwarded down the chain and be available for processing,
extracting metadata and generating location.

```rb
uploader.upload(file, { foo: "bar" }) # context hash is forwarded to all tasks around upload
```

Some options are actually recognized by Shrine (such as `:location`,
`:upload_options`, and `:metadata`), some are added by plugins, and the rest are
there just to provide additional context, for more flexibility in performing
tasks and more descriptive logging.

The attacher automatically includes additional `context` information for each
upload and delete operation:

* `context[:record]` – model instance where the file is attached
* `context[:name]` – name of the attachment attribute on the model
* `context[:action]` – identifier for the action being performed (`:cache`, `:store`, `:recache`, `:backup`, ...)

```rb
class VideoUploader < Shrine
  process(:store) do |io, context|
    trim_video(io, 300) if context[:record].user.free_plan?
  end
end
```

## Validation

Shrine can perform file validations for files assigned to the model. The
validations are defined inside the `Attacher.validate` block, and you can load
the `validation_helpers` plugin to get convenient file validation methods:

```rb
class DocumentUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 5*1024*1024, message: "is too large (max is 5 MB)"
    validate_mime_type_inclusion %w[application/pdf]
  end
end
```

```rb
user = User.new
user.cv = File.open("cv.pdf")
user.valid? #=> false
user.errors.to_hash #=> {:cv=>["is too large (max is 5 MB)"]}
```

See the [File Validation] guide and `validation_helpers` plugin documentation
for more details.

## Location

Before Shrine uploads a file, it generates a random location for it. By default
the hierarchy is flat; all files are stored in the root directory of the
storage. The `pretty_location` plugin provides a nice default hierarchy, but
you can also override `#generate_location` with a custom implementation:

```rb
class ImageUploader < Shrine
  def generate_location(io, context)
    type  = context[:record].class.name.downcase if context[:record]
    style = context[:version] == :original ? "originals" : "thumbs" if context[:version]
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
can also access the extracted metadata through `context[:metadata]`.

When uploading single files, it's possible to bypass `#generate_location` via
the uploader, by specifying `:location`:

```rb
uploader.upload(file, location: "some/specific/location.mp4")
```

## Direct uploads

To really improve the user experience, it's recommended to start uploading the
files asynchronously as soon they're selected. This way the UI is still
responsive during upload, so the user can fill in other fields while the files
are being uploaded, and if you display a progress bar they can see when the
upload will finish.

These asynchronous uploads will have to go to an endpoint separate from the one
where the form is submitted. This can be an endpoint in your app, or an
endpoint of a cloud service. In either case, the uploads should go to
*temporary* storage (`:cache`), to ensure there won't be any orphan files in
the primary storage (`:store`).

Once files are uploaded on the client side, their data can be submitted to the
server and attached to a record, just like with raw files. The only difference
is that they won't be additionally uploaded to temporary storage on assignment,
as they were already uploaded on the client side. Note that by default **Shrine
won't extract metadata from directly uploaded files**, instead it will just copy
metadata that was extacted on the client side; see [this section][metadata direct uploads]
for the rationale and instructions on how to opt in.

For handling client side uploads it's recommended to use **[Uppy]**. Uppy is a
very flexible modern JavaScript file upload library, which happens to integrate
nicely with Shrine.

### Simple direct upload

The simplest approach is creating an upload endpoint in your app that will
receive uploads and forward them to the specified storage. You can use the
`upload_endpoint` Shrine plugin to create a Rack app that handles uploads,
and mount it inside your application.

```rb
Shrine.plugin :upload_endpoint
```
```rb
# config.ru (Rack)
map "/images/upload" do
  run ImageUploader.upload_endpoint(:cache)
end

# OR

# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount ImageUploader.upload_endpoint(:cache) => "/images/upload"
end
```

The above will add a `POST /images/upload` route to your app. You can now use
Uppy's [XHR Upload][uppy xhr upload] plugin to upload selected files to this
endpoint, and have the uploaded file data submitted to your app. The client
side code for this will depend on your application, see [this
walkthrough][direct uploads walkthrough] for an example of adding simple direct
uploads from scratch.

If you wanted to implement this enpdoint yourself, this is how it could roughly
look like in Sinatra:

```rb
Shrine.plugin :rack_file # only if not using Rails
```
```rb
post "/images/upload" do
  uploader = ImageUploader.new(:cache)
  file     = Shrine.rack_file(params["file"]) # only `params[:file]` in Rails

  uploaded_file = uploader.upload(file)

  json uploaded_file.data
end
```

### Presigned direct upload

If you want to free your app from receiving file uploads, you can also upload
files directly to the cloud (AWS S3, Google Cloud etc). In this flow the client
is required to first fetch upload parameters from the server, and then use these
parameters to make the upload. The `presign_endpoint` Shrine plugin can be used
to create a Rack app that generates these upload parameters (provided that the
underlying storage implements `#presign`):

```rb
Shrine.plugin :presign_endpoint
```
```rb
# config.ru (Rack)
map "/s3/params" do
  run Shrine.presign_endpoint(:cache)
end

# OR

# config/routes.rb (Rails)
Rails.application.routes.draw do
  mount Shrine.presign_endpoint(:cache) => "/s3/params"
end
```

The above will add a `GET /s3/params` route to your app. You can now hook Uppy's
[AWS S3][uppy aws s3] plugin to this endpoint and have it upload directly to
S3. See [this walkthrough][direct S3 uploads walkthrough] that shows adding
direct S3 uploads from scratch, as well as the [Direct Uploads to S3][direct S3
uploads guide] guide that provides some useful tips. Also check out the
[Roda][roda demo] / [Rails][rails demo] demo app which implements multiple
uploads directly to S3.

If you wanted to implement this enpdoint yourself, this is how it could roughly
look like for S3 storage in Sinatra:

```rb
get "/s3/params" do
  storage  = Shrine.storages[:cache]
  location = SecureRandom.hex + File.extname(params["filename"].to_s)

  presign_data = storage.presign(location, content_type: params["type"])

  json presign_data
end
```

### Resumable direct upload

If your app is dealing with large uploads (e.g. videos), keep in mind that it
can be challening for your users to upload these large files to your app. Many
users might not have a great internet connection, and if it happens to break at
any point during uploading, they need to retry the upload from the beginning.

This problem has been solved by **[tus]**. tus is an open protocol for
resumable file uploads, which enables the client and the server to achieve
reliable file uploads even on unstable connections, by enabling the upload to
be resumed in case of interruptions, even after the browser was closed or the
device was shut down.

[tus-ruby-server] provides a Ruby server implemenation of the tus protocol.
Uppy's [Tus][uppy tus] plugin can then be configured to do resumable uploads to
a tus-ruby-server instance, and then the uploaded files can be attached to the
record with the help of [shrine-tus]. See [this walkthrough][resumable uploads
walkthrough] that adds resumable uploads from scratch, as well as the
[demo][resumable demo] for a complete example.

Alternatively, you can have resumable uploads directly to S3 using Uppy's [AWS
S3 Multipart][uppy aws s3 multipart] plugin, accompanied with the
[uppy-s3_multipart] gem.

## Backgrounding

Shrine is the first file attachment library designed for backgrounding support.
Moving phases of managing file attachments to background jobs is essential for
scaling and good user experience, and Shrine provides a `backgrounding` plugin
which makes it easy to plug in your favourite backgrounding library:

```rb
Shrine.plugin :backgrounding
Shrine::Attacher.promote { |data| PromoteJob.perform_async(data) }
Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
```
```rb
class PromoteJob
  include Sidekiq::Worker
  def perform(data)
    Shrine::Attacher.promote(data)
  end
end
```
```rb
class DeleteJob
  include Sidekiq::Worker
  def perform(data)
    Shrine::Attacher.delete(data)
  end
end
```

The above puts promoting (uploading cached file to permanent storage) and
deleting of files for all uploaders into background jobs using Sidekiq.
Obviously instead of Sidekiq you can use [any other backgrounding
library][backgrounding libraries].

## Clearing cache

Shrine doesn't automatically delete files uploaded to temporary storage, instead
you should set up a separate recurring task that will automatically delete old
cached files.

Most of Shrine storage classes come with a `#clear!` method, which you can call
in a recurring script. For FileSystem and S3 storage it would look like this:

```rb
# FileSystem storage
file_system = Shrine.storages[:cache]
file_system.clear!(older_than: Time.now - 7*24*60*60) # delete files older than 1 week
```
```rb
# S3 storage
s3 = Shrine.storages[:cache]
s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 } # delete files older than 1 week
```

Note that for AWS S3 you can also configure bucket lifecycle rules to do this
for you. This can be done either from the [AWS Console][S3 lifecycle console]
or via an [API call][S3 lifecycle API]:

```rb
require "aws-sdk-s3"

client = Aws::S3::Client.new(
  access_key_id:     "<YOUR KEY>",
  secret_access_key: "<YOUR SECRET>",
  region:            "<REGION>",
)

client.put_bucket_lifecycle_configuration(
  bucket: "<YOUR BUCKET>",
  lifecycle_configuration: {
    rules: [{
      expiration: { days: 7 },
      filter: { prefix: "cache/" },
      id: "cache-clear",
      status: "Enabled"
    }]
  }
)
```

## Logging

Shrine ships with the `logging` which automatically logs processing, uploading,
and deleting of files. This can be very helpful for debugging and performance
monitoring.

```rb
Shrine.plugin :logging
```
```
2015-10-09T20:06:06.676Z #25602: STORE[cache] ImageUploader[:avatar] User[29543] 1 file (0.1s)
2015-10-09T20:06:06.854Z #25602: PROCESS[store]: ImageUploader[:avatar] User[29543] 1-3 files (0.22s)
2015-10-09T20:06:07.133Z #25602: DELETE[destroyed]: ImageUploader[:avatar] User[29543] 3 files (0.07s)
```

## Settings

Each uploader can store generic settings in the `opts` hash, which can be
accessed in other uploader actions. You can store there anything that you find
convenient.

```rb
Shrine.opts[:type] = "file"

class DocumentUploader < Shrine; end
class ImageUploader < Shrine
  opts[:type] = "image"
end

DocumentUploader.opts[:type] #=> "file"
ImageUploader.opts[:type]    #=> "image"
```

Because `opts` is cloned in subclasses, overriding settings works with
inheritance. The `opts` hash is used internally by plugins to store
configuration.

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

[Shrine]: https://shrinerb.com
[plugin system]: https://twin.github.io/the-plugin-system-of-sequel-and-roda/
[FileSystem]: https://shrinerb.com/rdoc/classes/Shrine/Storage/FileSystem.html
[S3]: https://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html
[GCS]: https://github.com/renchap/shrine-google_cloud_storage
[Cloudinary]: https://github.com/shrinerb/shrine-cloudinary
[Transloadit]: https://github.com/shrinerb/shrine-transloadit
[activerecord plugin]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/Activerecord.html
[sequel plugin]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/Sequel.html
[hanami plugin]: https://github.com/katafrakt/hanami-shrine
[mongoid plugin]: https://github.com/shrinerb/shrine-mongoid
[image_processing]: https://github.com/janko-m/image_processing
[ImageMagick]: https://www.imagemagick.org/script/index.php
[libvips]: http://libvips.github.io/libvips/
[validation_helpers plugin]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/ValidationHelpers.html
[upload_endpoint plugin]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/UploadEndpoint.html
[presign_endpoint plugin]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/PresignEndpoint.html
[Uppy]: https://uppy.io
[tus]: https://tus.io
[uppy tus]: https://uppy.io/docs/tus/
[tus-ruby-server]: https://github.com/janko-m/tus-ruby-server
[backgrounding plugin]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/Backgrounding.html
[Advantages of Shrine]: https://shrinerb.com/rdoc/files/doc/advantages_md.html
[external storages]: https://shrinerb.com/#external
[creating storage]: https://shrinerb.com/rdoc/files/doc/creating_storages_md.html
[creating plugin]: https://shrinerb.com/rdoc/files/doc/creating_plugins_md.html
[Using Attacher]: https://shrinerb.com/rdoc/files/doc/attacher_md.html
[plugins]: https://shrinerb.com/#plugins
[`file`]: http://linux.die.net/man/1/file
[Extracting Metadata]: https://shrinerb.com/rdoc/files/doc/metadata_md.html
[File Processing]: https://shrinerb.com/rdoc/files/doc/processing_md.html
[File Validation]: https://shrinerb.com/rdoc/files/doc/validation_md.html
[metadata direct uploads]: https://github.com/shrinerb/shrine/blob/master/doc/metadata.md#direct-uploads
[uppy xhr upload]: https://uppy.io/docs/xhr-upload/
[direct uploads walkthrough]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-App-Uploads
[uppy aws s3]: https://uppy.io/docs/aws-s3/
[direct S3 uploads walkthrough]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-S3-Uploads<Paste>
[direct S3 uploads guide]: https://shrinerb.com/rdoc/files/doc/direct_s3_md.html
[roda demo]: https://github.com/shrinerb/shrine/tree/master/demo
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
[shrine-tus]: https://github.com/shrinerb/shrine-tus
[uppy aws s3 multipart]: https://uppy.io/docs/aws-s3-multipart/
[uppy-s3_multipart]: https://github.com/janko-m/uppy-s3_multipart
[resumable uploads walkthrough]: https://github.com/shrinerb/shrine/wiki/Adding-Resumable-Uploads
[resumable demo]: https://github.com/shrinerb/shrine-tus-demo
[backgrounding libraries]: https://github.com/shrinerb/shrine/wiki/Backgrounding-libraries
[S3 lifecycle Console]: http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html
[S3 lifecycle API]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_bucket_lifecycle_configuration-instance_method
[Roda]: https://github.com/jeremyevans/roda
[Refile]: https://github.com/refile/refile
[CoC]: https://github.com/shrinerb/shrine/blob/master/CODE_OF_CONDUCT.md
[MIT License]: http://opensource.org/licenses/MIT
