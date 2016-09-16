# Shrine

Shrine is a toolkit for file attachments in Ruby applications.

If you're not sure why you should care, you're encouraged to read the
[motivation behind creating Shrine][motivation].

## Resources

- Documentation: [shrinerb.com](http://shrinerb.com)
- Source: [github.com/janko-m/shrine](https://github.com/janko-m/shrine)
- Bugs: [github.com/janko-m/shrine/issues](https://github.com/janko-m/shrine/issues)
- Help & Discussion: [groups.google.com/group/ruby-shrine](https://groups.google.com/forum/#!forum/ruby-shrine)

## Quick start

Add Shrine to the Gemfile and write an initializer:

```rb
gem "shrine"
```

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"), # temporary
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"), # permanent
}

Shrine.plugin :sequel # :activerecord
Shrine.plugin :cached_attachment_data # for forms
```

Next write a migration to add a column which will hold attachment data, and run
it:

```rb
Sequel.migration do                           # class AddImageDataToPhotos < ActiveRecord::Migration
  change do                                   #   def change
    add_column :photos, :image_data, :text    #     add_column :photos, :image_data, :text
  end                                         #   end
end                                           # end
```

Now you can create an uploader class for the type of files you want to upload,
and make your model handle attachments:

```rb
class ImageUploader < Shrine
  # plugins and uploading logic
end
```

```rb
class Photo < Sequel::Model # ActiveRecord::Base
  include ImageUploader[:image]
end
```

This creates an `image` attachment attribute which accepts files. Let's now
add the form fields needed for attaching files:

```erb
<form action="/photos" method="post" enctype="multipart/form-data">
  <input name="photo[image]" type="hidden" value="<%= @photo.cached_image_data %>">
  <input name="photo[image]" type="file">
</form>

<!-- Rails: -->
<%= form_for @photo do |f| %>
  <%= f.hidden_field :image, value: @photo.cached_image_data %>
  <%= f.file_field :image %>
<% end %>
```

Now assigning the request parameters in your router/controller will
automatically handle the image attachment:

```rb
post "/photos" do
  Photo.create(params[:photo])
end
```

When a Photo is created with the image attached, you can display the image via
its URL:

```erb
<img src="<%= @photo.image_url %>">
```

## Attachment

When we assign an IO-like object to the record, Shrine will upload it to the
registered `:cache` storage, which acts as a temporary storage, and write the
location, storage, and metadata of the uploaded file to a single
`<attachment>_data` column:

```rb
photo = Photo.new
photo.image = File.open("waterfall.jpg")
photo.image_data #=> '{"storage":"cache","id":"9260ea09d8effd.jpg","metadata":{...}}'

photo.image      #=> #<Shrine::UploadedFile>
photo.image_url  #=> "/uploads/cache/9260ea09d8effd.jpg"
```

The Shrine attachment module added the following methods to the `Photo` model:

* `#image=` – caches the file and saves the result into `image_data`
* `#image` – returns `Shrine::UploadedFile` instantiated from `image_data`
* `#image_url` – calls `image.url` if attachment is present, otherwise returns nil
* `#image_attacher` - instance of `Shrine::Attacher` which handles attaching

In addition to assigning new files, you can also assign already cached files
using their JSON representation:

```rb
photo.image = '{
  "storage": "cache",
  "id": "9260ea09d8effd.jpg",
  "metadata": { ... }
}'
```

This allows Shrine to retain uploaded files in case of validation errors, and
handle [direct uploads], via the hidden form field.

The ORM plugin that we loaded adds appropriate callbacks, so when record is
saved the attachment is uploaded to permanent storge (`:store`), and when
record is destroyed the attachment is destroyed as well:

```rb
photo.image = File.open("waterfall.jpg")
photo.image_url #=> "/uploads/cache/0sdfllasfi842.jpg"

photo.save
photo.image_url #=> "/uploads/store/l02kladf8jlda.jpg"

photo.destroy
photo.image.exists? #=> false
```

The ORM plugin will also delete replaced attachments:

```rb
photo.update(image: new_file) # changes the attachment and deletes previous
# or
photo.update(image: nil)      # removes the attachment and deletes previous
```

In all these examples we used `image` as the name of the attachment, but we can
create attachment modules for any kind of attachments:

```rb
class VideoUploader < Shrine
  # video attachment logic
end
```
```rb
class Movie < Sequel::Model
  include VideoUploader[:video] # uses "video_data" column
end
```

### Attacher

The model attachment interface under-the-hood just delegates to a
`Shrine::Attacher` object. If you don't want to add additional methods to your
model, or you prefer explicitness, you can use `Shrine::Attacher` directly:

```rb
attacher = ImageUploader::Attacher.new(photo, :image) # equivalent to `photo.image_attacher`
attacher.assign(file)                                 # equivalent to `photo.image = file`
attacher.get                                          # equivalent to `photo.image`
```

See [Using Attacher] guide for more details.

### Multiple files

Sometimes we want to allow users to upload multiple files at once. This can be
achieved with by adding a `multiple` HTML attribute to the file field: `<input
type="file" multiple>`.

Shrine doesn't accept multiple files on single a attachment attribute, but you
can instead attach each file to a separate database record, which is a much
more flexible solution.

The best way is to [directly upload][direct uploads] selected files, and then
send the data of uploaded files as nested attributes for associated records.
Alternatively you can send all selected files at once, and then transform them
into nested association attributes in the controller.

## Uploader

"Uploaders" are subclasses of `Shrine`, and this is where we define all our
attachment logic. Uploaders act as a wrappers around a storage, delegating all
service-specific logic to the storage. They don't know anything about models
and are stateless; they are only in charge of uploading, processing and
deleting files.

```rb
uploader = DocumentUploader.new(:store)
uploaded_file = uploader.upload(File.open("resume.pdf"))
uploaded_file #=> #<Shrine::UploadedFile>
uploaded_file.to_json #=> '{"storage":"store","id":"0sdfllasfi842.pdf","metadata":{...}}'
```

Shrine requires the input for uploading to be an IO-like object. So, `File`,
`Tempfile` and `StringIO` instances are all valid inputs. The object doesn't
have to be an actual IO, it's enough that it responds to: `#read(*args)`,
`#size`, `#eof?`, `#rewind` and `#close`. `ActionDispatch::Http::UploadedFile`
is one such object, as well as `Shrine::UploadedFile` itself.

The result of uploading is a `Shrine::UploadedFile` object, which represents
the uploaded file on the storage, and is defined by its underlying data hash.

```rb
uploaded_file.url      #=> "uploads/938kjsdf932.mp4"
uploaded_file.metadata #=> {...}
uploaded_file.download #=> #<Tempfile:/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/20151004-74201-1t2jacf.mp4>
uploaded_file.exists?  #=> true
uploaded_file.open { |io| ... }
uploaded_file.delete
# ...
```

This is the same object that is returned when we access the attachment through
the record:

```rb
photo.image #=> #<Shrine::UploadedFile>
```

### Plugins

Shrine comes with a small core which provides only the essential functionality,
and any additional features are available via plugins. This way you can choose
exactly what and how much Shrine does for you. See the [website] for a complete
list of plugins.

The plugin system respects inheritance, so you can choose to load a plugin
globally or only for a specific uploader.

```rb
Shrine.plugin :logging # enables logging for all uploaders

class ImageUploader < Shrine
  plugin :backup # stores backups only for this uploader and its descendants
end
```

## Processing

Shrine allows you to perform file processing in functional style; you receive
the original file as the input, and return processed files as the output.

Processing can be performed whenever a file is uploaded. On attaching this
happens twice; first the raw file is cached to temporary storage ("cache"
action), then when the record is saved the cached file is "promoted" to
permanent storage ("store" action). We generally want to process on the "store"
action, because it happens after file validations and can be backgrounded.

```rb
class ImageUploader < Shrine
  plugin :processing

  process(:store) do |io, context|
    # ...
  end
end
```

Ok, now how do we do the actual processing? Well, Shrine actually doesn't ship
with any file processing functionality, because that is a generic problem that
belongs in separate libraries. If the type of files you're uploading are
images, I created the [image_processing] gem which you can use with Shrine:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :processing

  process(:store) do |io, context|
    resize_to_limit(io.download, 700, 700)
  end
end
```

Since here `io` is a cached `Shrine::UploadedFile`, we need to download it to
a `File`, which is what image_processing recognizes.

### Versions

Sometimes we want to generate multiple files as the result of processing. If
we're uploading images, we might want to store various thumbnails alongside the
original image. If we're uploading videos, we might want to save a screenshot
or transcode it into different formats.

To save multiple files, we just need to load the `versions` plugin, and then in
`#process` we can return a Hash of files:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :processing
  plugin :versions

  process(:store) do |io, context|
    size_700 = resize_to_limit(io.download, 700, 700)
    size_500 = resize_to_limit(size_700,    500, 500)
    size_300 = resize_to_limit(size_500,    300, 300)

    {large: size_700, medium: size_500, small: size_300}
  end
end
```

Being able to define processing on instance-level like this provides a lot of
flexibility. For example, you can choose to process files in a certain order
for maximum performance, and you can also add parallelization. It is
recommended to load the `delete_raw` plugin for automatically deleting processed
files after uploading.

Each version will be saved to the attachment column, and the attachment getter
will simply return a Hash of `Shrine::UploadedFile` objects:

```rb
photo.image #=> {large: ..., medium: ..., small: ...}

# With the store_dimensions plugin (requires fastimage gem)
photo.image[:large].width  #=> 700
photo.image[:medium].width #=> 500
photo.image[:small].width  #=> 300

# The plugin expands this method to accept version names.
photo.image_url(:large) #=> "..."
```

### Custom processing

Your processing tool doesn't have to be in any way designed for Shrine
([image_processing] is a generic library), you only need to return processed
files as IO objects, e.g. `File` objects. Here's an example of processing a
video with [ffmpeg]:

```rb
require "streamio-ffmpeg"

class VideoUploader < Shrine
  plugin :processing
  plugin :versions

  process(:store) do |io, context|
    mov        = io.download
    video      = Tempfile.new(["video", ".mp4"], binmode: true)
    screenshot = Tempfile.new(["screenshot", ".jpg"], binmode: true)

    movie = FFMPEG::Movie.new(mov.path)
    movie.transcode(video.path)
    movie.screenshot(screenshot.path)

    mov.delete

    {video: video, screenshot: screenshot}
  end
end
```

## Context

You may have noticed the `context` variable floating around as the second
argument for processing. This variable is present all the way from input file
to uploaded file, and can contain useful information depending on the situation:

* `context[:record]` -- the model instance
* `context[:name]` -- attachment name on the model
* `context[:action]` -- identifier for the action being performed (`:cache`, `:store`, `:recache`, `:backup`, ...)
* `context[:version]` -- version name of the IO in the argument
* ...

The `context` is useful for doing conditional processing, validation,
generating location etc, and it is also used by some plugins internally.

## Metadata

Shrine automatically extracts and stores available file metadata:

```rb
photo = Photo.create(image: image)

photo.image.metadata #=>
# {
#   "filename"  => "nature.jpg",
#   "mime_type" => "image/jpeg",
#   "size"      => 345993,
# }

photo.image.original_filename #=> "nature.jpg"
photo.image.extension         #=> "jpg"
photo.image.mime_type         #=> "image/jpeg"
photo.image.size              #=> 345993
```

### MIME type

By default, "mime_type" is inherited from `#content_type` of the uploaded file,
which is set from the "Content-Type" request header, which is determined by the
browser solely based on the file extension. This means that by default Shrine's
"mime_type" is *not* guaranteed to hold the actual MIME type of the file.

To help with that Shrine provides the `determine_mime_type` plugin, which by
default uses the UNIX [file] utility to determine the actual MIME type:

```rb
Shrine.plugin :determine_mime_type
```
```rb
File.write("image.jpg", "<?php ... ?>") # PHP file with a .jpg extension
photo = Photo.create(image: File.open("image.jpg"))
photo.image.mime_type #=> "text/x-php"
```

### Custom metadata

You can also extract and store completely custom metadata with the
`add_metadata` plugin:

```rb
require "mini_magick"

class ImageUploader < Shrine
  plugin :add_metadata

  add_metadata :exif do |io, context|
    MiniMagick::Image.new(io.path).exif
  end
end
```
```rb
photo.image.metadata["exif"]
# or
photo.image.exif
```

## Validation

Validations are registered inside a `Attacher.validate` block, and you can load
the `validation_helpers` plugin to get some convenient file validation methods:

```rb
class VideoUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 50*1024*1024, message: "is too large (max is 50 MB)"
    validate_mime_type_inclusion ["video/mp4"]
  end
end
```

```rb
trailer = Trailer.new
trailer.video = File.open("matrix.mp4")
trailer.valid? #=> false
trailer.errors.to_hash #=> {video: ["is too large (max is 50 MB)"]}
```

You can also do custom validations:

```rb
class VideoUploader < Shrine
  Attacher.validate do
    errors << "is longer than 5 minutes" if get.duration > 300
  end
end
```

The `Attacher.validate` block is executed in context of a `Shrine::Attacher`
instance:

```rb
class VideoUploader < Shrine
  Attacher.validate do
    self   #=> #<Shrine::Attacher>

    get    #=> #<Shrine::UploadedFile>
    record # the model instance
    errors # array of error messages for this file
  end
end
```

## Locations

Before Shrine uploads a file, it generates a random location for it. By
default the hierarchy is flat, all files are stored in the root of the storage.
If you want that each attachment has its own directory, you can load the
`pretty_location` plugin:

```rb
Shrine.plugin :pretty_location
```
```rb
photo = Photo.create(image: File.open("nature.jpg"))
photo.image.id #=> "photo/34/image/34krtreds2df.jpg"
```

If you want to generate locations on your own, you can override
`Shrine#generate_location`:

```rb
class ImageUploader < Shrine
  def generate_location(io, context)
    if context[:record]
      "#{context[:record].class}/#{super}"
    else
      super
    end
  end
end
```

Note that there should always be a random component in the location, so that
dirty tracking is detected properly; you can use `Shrine#generate_uid`. Inside
`#generate_location` you can access the extracted metadata through
`context[:metadata]`.

When using the uploader directly, it's possible to bypass `#generate_location`
by passing a `:location`:

```rb
uploader = MyUploader.new(:store)
file = File.open("nature.jpg")
uploader.upload(file, location: "some/specific/location.jpg")
```

## Storage

"Storages" are objects which know how to manage files on a particular service.
Other than [FileSystem], Shrine also ships with Amazon [S3] storage:

```rb
gem "aws-sdk", "~> 2.1"
```
```rb
require "shrine/storage/s3"

Shrine.storages[:store] = Shrine::Storage::S3.new(
  access_key_id:     "<ACCESS_KEY_ID>",      # "xyz"
  secret_access_key: "<SECRET_ACCESS_KEY>",  # "abc"
  region:            "<REGION>",             # "eu-west-1"
  bucket:            "<BUCKET>",             # "my-bucket"
)
```

```rb
photo = Photo.new(image: File.open("image.png"))
photo.image_url #=> "/uploads/cache/j4k343ui12ls9.png"
photo.save
photo.image_url #=> "https://my-bucket.s3.amazonaws.com/0943sf8gfk13.png"
```

Note that any options passed to `image_url` will be forwarded to the underlying
storage, see the documentation of the storage that you're using for which URL
options it supports.

You can see the full documentation for [FileSystem] and [S3] storages. There
are also many other Shrine storages available, see [External] section on the
website.

### Upload options

Many storages accept additional upload options, which you can pass via the
`upload_options` plugin, or manually when uploading:

```rb
uploader = MyUploader.new(:store)
uploader.upload(file, upload_options: {acl: "private"})
```

### Clearing cache

From time to time you'll want to clean your temporary storage from old files.
Amazon S3 provides [a built-in solution][s3 lifecycle], and for FileSystem you
can put something like this in your Rake task:

```rb
file_system = Shrine.storages[:cache]
file_system.clear!(older_than: Time.now - 7*24*60*60) # delete files older than 1 week
```

## Direct uploads

Shrine comes with a `direct_upload` plugin for asynchronous uploads to your
app or an external service. It provides a [Roda] endpoint which you can mount
in your app:

```rb
gem "roda"
```
```rb
Shrine.plugin :direct_upload
```
```rb
Rails.application.routes.draw do
  mount ImageUploader::UploadEndpoint => "/images"
end
```

This endpoint provides the following routes:

* `POST /images/cache/upload` - for direct uploads to your app
* `GET /images/cache/presign` - for direct uploads to external service

These routes can be used to asynchronously start caching the file the moment
the user selects it, using JavaScript file upload libraries like
[jQuery-File-Upload], [Dropzone] or [FineUploader].

See the [direct_upload] plugin documentation and [Direct Uploads to S3] guide
for more details, as well as the [Roda][roda_demo] and [Rails][rails_demo]
demo apps which implement multiple uploads directly to S3.

## Backgrounding

Shrine is the first file upload library designed for backgrounding support.
Moving phases of managing file attachments to background jobs is essential for
scaling and good user experience, and Shrine provides a `backgrounding` plugin
which makes it really easy to plug in your favourite backgrounding library:

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

The above puts all promoting (uploading cached file to permanent storage) and
deleting of files into a background Sidekiq job. Obviously instead of Sidekiq
you can use [any other backgrounding library][backgrounding libraries].

The main advantages of Shrine's backgrounding support over other file upload
libraries are:

* **User experience** – After starting the background job, Shrine will save the
  record with the cached attachment so that it can be immediately shown to the
  user. With other file upload libraries users cannot see the file until the
  background job has finished.
* **Simplicity** – Instead of writing the workers for you, Shrine allows you
  to use your own workers in a very simple way. Also, no extra columns are
  required.
* **Generality** – The above solution will automatically work for all uploaders,
  types of files and models.
* **Safety** – All of Shrine's code has been designed to take delayed storing
  into account, and concurrent requests are handled well.

## On-the-fly processing

Shrine allows you to define processing that will be performed on upload.
However, what if you want to have processing performed on-the-fly when the URL
is requested? Unlike Refile or Dragonfly, Shrine doesn't come with an image
server built in; instead it expects you to integrate any of the existing
generic image servers.

Shrine has integrations for many commercial on-the-fly processing services,
including [Cloudinary], [Imgix] and [Uploadcare].

If you don't want to use a commercial service, [Attache] and [Dragonfly] are
great open-source image servers. For Attache a Shrine integration is in
progress, while for Dragonfly it is not needed.

## Chunked & Resumable uploads

When you're accepting large file uploads, you normally want to split it into
multiple chunks. This way if an upload fails, it is just for one chunk and can
be retried, while the previous chunks remain uploaded.

[Tus][tus] is an open protocol for resumable file uploads, which enables the
client and the server to achieve reliable file uploads, even on unstable
networks, with the possibility to resume the upload even after the browser is
closed or the device shut down. You can use a client library like
[tus-js-client] to upload the file to [tus-ruby-server], and attach the
uploaded file to a record using [shrine-url]. See [shrine-tus-demo] for an
example integration.

Another option might be to do chunked uploads directly to your storage service,
if the storage service supports it (e.g. Amazon S3 or Google Cloud Storage).

## Inspiration

Shrine was heavily inspired by [Refile] and [Roda]. From Refile it borrows the
idea of "backends" (here named "storages"), attachment interface, and direct
uploads. From Roda it borrows the implementation of an extensible [plugin
system].

## Similar libraries

* Paperclip
* CarrierWave
* Dragonfly
* Refile

## License

The gem is available as open source under the terms of the [MIT License].

[image_processing]: https://github.com/janko-m/image_processing
[fastimage]: https://github.com/sdsykes/fastimage
[file]: http://linux.die.net/man/1/file
[image bombs]: https://www.bamsoftware.com/hacks/deflate.html
[aws-sdk]: https://github.com/aws/aws-sdk-ruby
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
[Dropzone]: https://github.com/enyo/dropzone
[FineUploader]: https://github.com/FineUploader/fine-uploader
[Roda]: https://github.com/jeremyevans/roda
[Refile]: https://github.com/refile/refile
[plugin system]: http://twin.github.io/the-plugin-system-of-sequel-and-roda/
[MIT License]: http://opensource.org/licenses/MIT
[ships with over 35 plugins]: http://shrinerb.com#plugins
[motivation]: https://twin.github.io/better-file-uploads-with-shrine-motivation/
[FileSystem]: http://shrinerb.com/rdoc/classes/Shrine/Storage/FileSystem.html
[S3]: http://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html
[External]: http://shrinerb.com#external
[`Shrine::UploadedFile`]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/Base/FileMethods.html
[direct uploads]: #direct-uploads
[ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[direct_upload]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/DirectUpload.html
[Cloudinary]: https://github.com/janko-m/shrine-cloudinary
[Imgix]: https://github.com/janko-m/shrine-imgix
[Uploadcare]: https://github.com/janko-m/shrine-uploadcare
[Attache]: https://github.com/choonkeat/attache
[roda_demo]: /demo
[rails_demo]: https://github.com/erikdahlstrand/shrine-rails-example
[Direct Uploads to S3]: http://shrinerb.com/rdoc/files/doc/direct_s3_md.html
[website]: http://shrinerb.com
[backgrounding libraries]: https://github.com/janko-m/shrine/wiki/Backgrounding-libraries
[tus]: http://tus.io
[tus-ruby-server]: https://github.com/janko-m/tus-ruby-server
[tus-js-client]: https://github.com/tus/tus-js-client
[shrine-tus-demo]: https://github.com/janko-m/shrine-tus-demo
[shrine-url]: https://github.com/janko-m/shrine-url
[s3 lifecycle]: http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html
[Dragonfly]: http://markevans.github.io/dragonfly/
[Using Attacher]: http://shrinerb.com/rdoc/files/doc/attacher_md.html
