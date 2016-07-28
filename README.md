# Shrine

Shrine is a toolkit for handling file uploads in Ruby applications.

If you're new, you're encouraged to read the [introductory blog post] which
explains the motivation behind Shrine.

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
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
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

And add attachment fields to the Photo form:

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

Now when a Photo is created with the image attached, you can get the URL to
the image:

```erb
<img src="<%= @photo.image_url %>">
```

## Attachment

When we assign an IO-like object to the record, Shrine will upload it to the
registered `:cache` storage, which acts as a temporary storage, and write the
location/storage/metadata of the uploaded file to a single `<attachment>_data`
column:

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

In addition to assigning new files, you can also assign already uploaded files:

```rb
photo.image = '{"storage":"cache","id":"9260ea09d8effd.jpg","metadata":{...}}'
```

This allows Shrine to retain uploaded files in case of validation errors, and
handle [direct uploads], via the hidden form field.

The ORM plugin that we loaded will upload the attachment to permanent storage
(`:store`) when the record is saved, and delete the attachment when record
is destroyed:

```rb
photo.image = File.open("waterfall.jpg")
photo.image_url #=> "/uploads/cache/0sdfllasfi842.jpg"

photo.save
photo.image_url #=> "/uploads/store/l02kladf8jlda.jpg"

photo.destroy
photo.image.exists? #=> false
```

In these examples we used `image` as the name of the attachment, but we can
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
uploaded_file.open { |io| ... }
uploaded_file.exists?  #=> true
uploaded_file.delete
# ...
```

This is the same object that is returned when we access the attachment through
the record:

```rb
photo.image #=> #<Shrine::UploadedFile>
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

To save multiple files, we just need to load the versions plugin, and then in
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
recommended to load the delete_raw plugin for automatically deleting processed
files after uploading.

Each version will be saved to the attachment column, and the attachment getter
will simply return a Hash of `Shrine::UploadedFile` objects:

```rb
photo.image #=> {large: ..., medium: ..., small: ...}

# With the store_dimensions plugin
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
to uploaded file, and contains any additional information that can affect the
upload:

* `context[:record]` -- the model instance
* `context[:name]` -- attachment name on the model
* `context[:action]` -- identifier for the action being performed (`:cache`, `:store`, `:recache`, `:backup`, ...)
* `context[:version]` -- version name of the IO in the argument
* ...

The `context` is useful for doing conditional processing, validation,
generating location etc, and it is also used by some plugins internally.

## Validation

Validations are registered by calling `Attacher.validate`, and are best done
with the validation_helpers plugin:

```rb
class DocumentUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    # Evaluated inside an instance of Shrine::Attacher.
    if record.resume?
      validate_max_size 10*1024*1024, message: "is too large (max is 10 MB)"
      validate_mime_type_inclusion ["application/pdf"]
    end
  end
end
```

```rb
document = Document.new(resume: true)
document.file = File.open("resume.pdf")
document.valid? #=> false
document.errors.to_hash #=> {file: ["is too large (max is 2 MB)"]}
```

## Metadata

Shrine automatically extracts and stores general file metadata:

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

To help with that Shrine provides the determine_mime_type plugin, which by
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

You can also extract and store completely custom metadata with the metadata
plugin:

```rb
require "mini_magick"

class ImageUploader < Shrine
  plugin :add_metadata

  add_metadata "exif" do |io, context|
    MiniMagick::Image.new(io.path).exif
  end
end
```

Note that you should always rewind the `io` if you read from it.

## Locations

Before Shrine uploads a file, it generates a random location for it. By
default the hierarchy is flat, all files are stored in the root of the storage.
If you want that each attachment has its own directory, you can load the
pretty_location plugin:

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
upload_options plugin, or manually when uploading:

```rb
uploader = MyUploader.new(:store)
uploader.upload(file, upload_options: {acl: "private"})
```

## Direct uploads

Shrine comes with a [direct_upload] plugin which provides a [Roda] endpoint that
accepts file uploads. This allows you to asynchronously start caching the file
the moment the user selects it via AJAX (e.g. using the [jQuery-File-Upload] JS
library).

```rb
Shrine.plugin :direct_upload # Provides a Roda endpoint
```
```rb
Rails.application.routes.draw do
  mount VideoUploader::UploadEndpoint => "/videos"
end
```
```js
$('[type="file"]').fileupload({
  url:       '/videos/cache/upload',
  paramName: 'file',
  add:       function(e, data) { /* Disable the submit button */ },
  progress:  function(e, data) { /* Add a nice progress bar */ },
  done:      function(e, data) { /* Fill in the hidden field with the result */ }
});
```

Along with the upload route, this endpoint also includes a route for generating
presigns for direct uploads to 3rd-party services like Amazon S3. See the
[direct_upload] plugin documentation for more details, as well as the
[Roda](https://github.com/janko-m/shrine-example)/[Rails](https://github.com/erikdahlstrand/shrine-rails-example)
example apps which demonstrate multiple uploads directly to S3.

## Backgrounding

Shrine is the first file upload library designed for backgrounding support.
Moving phases of managing attachments to background jobs is essential for
scaling and good user experience, and Shrine provides a backgrounding plugin
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
you can use any other backgrounding library.

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

## Clearing cache

From time to time you'll want to clean your temporary storage from old files.
Amazon S3 provides [a built-in solution](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html),
and for FileSystem you can put something like this in your Rake task:

```rb
file_system = Shrine.storages[:cache]
file_system.clear!(older_than: Time.now - 7*24*60*60) # delete files older than 1 week
```

## Plugins

Shrine comes with a small core which provides only the essential functionality,
and any additional features are available via plugins. This way you can choose
exactly what and how much Shrine does for you. Shrine itself [ships with over
35 plugins], most of which I didn't cover here.

The plugin system respects inheritance, so you can choose which plugins will
be applied to which uploaders:

```rb
Shrine.plugin :logging # enables logging for all uploaders

class ImageUploader < Shrine
  plugin :store_dimensions # stores dimensions only for this uploader and its descendants
end
```

## On-the-fly processing

Shrine allows you to define processing that will be performed on upload.
However, what if want to perform processing on-the-fly, only when the URL is
requested? Unlike Refile or Dragonfly, Shrine doesn't come with an image server
built in, instead it expects you to integrate any of the existing generic image
servers.

Shrine has integrations for many commercial on-the-fly processing services, so
you can use [shrine-cloudinary], [shrine-imgix] or [shrine-uploadcare].

If you don't want to use a commercial service, [Attache] is a great open-source
image server. There isn't a Shrine integration written for it yet, but it
should be fairly easy to write one.

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
[Roda]: https://github.com/jeremyevans/roda
[Refile]: https://github.com/refile/refile
[plugin system]: http://twin.github.io/the-plugin-system-of-sequel-and-roda/
[MIT License]: http://opensource.org/licenses/MIT
[example app]: https://github.com/janko-m/shrine-example
[ships with over 35 plugins]: http://shrinerb.com#plugins
[introductory blog post]: http://twin.github.io/introducing-shrine/
[FileSystem]: http://shrinerb.com/rdoc/classes/Shrine/Storage/FileSystem.html
[S3]: http://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html
[External]: http://shrinerb.com#external
[`Shrine::UploadedFile`]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/Base/FileMethods.html
[direct uploads]: #direct-uploads
[ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[direct_upload]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/DirectUpload.html
[shrine-cloudinary]: https://github.com/janko-m/shrine-cloudinary
[shrine-imgix]: https://github.com/janko-m/shrine-imgix
[shrine-uploadcare]: https://github.com/janko-m/shrine-uploadcare
[Attache]: https://github.com/choonkeat/attache
