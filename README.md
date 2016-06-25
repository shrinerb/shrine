# Shrine

Shrine is a toolkit for handling file uploads in Ruby applications.

If you're new, you're encouraged to read the [introductory blog post] which
explains the motivation behind Shrine.

## Resources

- Documentation: [shrinerb.com](http://shrinerb.com)
- Source: [github.com/janko-m/shrine](https://github.com/janko-m/shrine)
- Bugs: [github.com/janko-m/shrine/issues](https://github.com/janko-m/shrine/issues)
- Help & Discussion: [groups.google.com/group/ruby-shrine](https://groups.google.com/forum/#!forum/ruby-shrine)

## Installation

```rb
gem "shrine"
```

Shrine has been tested on MRI 2.1, MRI 2.2, MRI 2.3 and JRuby.

## Basics

Here's an example showing how basic file upload works in Shrine:

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages[:file_system] = Shrine::Storage::FileSystem.new("uploads")

uploader = Shrine.new(:file_system)

uploaded_file = uploader.upload(File.open("movie.mp4"))
uploaded_file      #=> #<Shrine::UploadedFile>
uploaded_file.data #=>
# {
#   "storage"  => "file_system",
#   "id"       => "9260ea09d8effd.mp4",
#   "metadata" => {...},
# }
```

Let's see what's going on here:

First we registered the storage we want to use under a name. Storages are plain
Ruby classes which encapsulate file management on a particular service. We can
then instantiate `Shrine` as a wrapper around that storage. A call to `upload`
uploads the given file to the underlying storage.

The argument to `upload` needs to be an IO-like object. So, `File`, `Tempfile`
and `StringIO` are all valid arguments. The object doesn't have to be an actual
IO, though, it's enough that it responds to these 5 methods: `#read(*args)`,
`#size`, `#eof?`, `#rewind` and `#close`. `ActionDispatch::Http::UploadedFile`
is one such object, as well as `Shrine::UploadedFile` itself.

The result of uploading is a `Shrine::UploadedFile` object, which represents
the uploaded file on the storage. It is defined solely by its data hash. We can
do a lot with it:

```rb
uploaded_file.url      #=> "uploads/938kjsdf932.mp4"
uploaded_file.metadata #=> {...}
uploaded_file.read     #=> "..."
uploaded_file.exists?  #=> true
uploaded_file.download #=> #<Tempfile:/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/20151004-74201-1t2jacf.mp4>
uploaded_file.delete
# ...
```

## Attachment

In web applications we usually want work with files on a higher level. We want
to treat them as "attachments" to records, by persisting their information to a
database column and tying their lifecycle to the record. For this Shrine offers
a higher-level attachment interface.

First we need to register temporary and permanent storage which will be used
internally:

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
}
```

The `:cache` and `:store` are only special in terms that they will be used
automatically (but that can be changed with the default_storage plugin). Next,
we create an uploader class specific to the type of attachment we want, so that
later we can have different uploading logic for different attachment types.

```rb
class ImageUploader < Shrine
  # your logic for uploading images
end
```

Finally, to add an attachment to a model, we generate a named "attachment"
module using the uploader and include it:

```rb
class Photo
  include ImageUploader[:image] # requires "image_data" attribute
end
```

Now our model has gained special methods for attaching files:

```rb
photo = Photo.new
photo.image = File.open("nature.jpg") # uploads the file to cache
photo.image      #=> #<Shrine::UploadedFile>
photo.image_url  #=> "/uploads/cache/9260ea09d8effd.jpg"
photo.image_data #=> "{\"storage\":\"cache\",\"id\":\"9260ea09d8effd.jpg\",\"metadata\":{...}}"
```

The attachment module has added `#image`, `#image=` and `#image_url`
methods to our `Photo`, using regular module inclusion.

```rb
Shrine[:image] #=> #<Shrine::Attachment(image)>
Shrine[:image].is_a?(Module) #=> true
Shrine[:image].instance_methods #=> [:image=, :image, :image_url, :image_attacher]

Shrine[:document] #=> #<Shrine::Attachment(document)>
Shrine[:document].instance_methods #=> [:document=, :document, :document_url, :document_attacher]

# Expanded forms
Shrine.attachment(:image)
Shrine::Attachment.new(:document)
```

* `#image=` – caches the file and saves JSON data into `image_data`
* `#image` – returns a `Shrine::UploadedFile` based on data from `image_data`
* `#image_url` – calls `image.url` if attachment is present, otherwise returns nil.

This is how you should create a form for a `@photo`:

```rb
Shrine.plugin :cached_attachment_data
```
```erb
<form action="/photos" method="post" enctype="multipart/form-data">
  <input name="photo[image]" type="hidden" value="<%= @photo.cached_image_data %>">
  <input name="photo[image]" type="file">
</form>
```

The "file" field is for file upload, while the "hidden" field is to make the
file persist in case of validation errors, and for direct uploads. Note that
the hidden field should always be *before* the file field.

This code works because `#image=` also accepts an already cached file via its
JSON representation (which is what `#cached_image_data` returns):

```rb
photo.image = '{"id":"9jsdf02kd", "storage":"cache", "metadata": {...}}'
```

### ORM

Even though you can use Shrine's attachment interface with plain Ruby objects,
it's much more common to use it with an ORM. Shrine ships with plugins for
Sequel and ActiveRecord ORMs. It uses the `<attachment>_data` column for
storing data for uploaded files, so you'll need to add it in a migration.

```rb
add_column :movies, :video_data, :text # or a JSON column
```
```rb
Shrine.plugin :sequel # or :activerecord
```
```rb
class Movie < Sequel::Model
  include VideoUploader[:video]
end
```

In addition to getters and setters, the ORM plugins add the appropriate
callbacks:

```rb
movie.video = File.open("video.mp4")
movie.video_url #=> "/uploads/cache/0sdfllasfi842.mp4"

movie.save
movie.video_url #=> "/uploads/store/l02kladf8jlda.mp4"

movie.destroy
movie.video.exists? #=> false
```

First the raw file is cached to temporary storage on assignment, then on saving
the cached file is uploaded to permanent storage. Destroying the record
destroys the attachment.

*NOTE: The record will first be saved with the cached attachment, and
afterwards (in an "after commit" hook) updated with the stored attachment. This
is done so that processing/storing isn't performed inside a database
transaction. If you're doing processing, there will be a period of time when
the record will be saved with an unprocessed attachment, so you may need to
account for that.*

## Processing

Whenever a file is uploaded, `Shrine#process` is called, and this is where
you're expected to define your processing.

```rb
class ImageUploader < Shrine
  def process(io, context)
    # ...
  end
end
```

Shrine's uploaders are stateless; the `#process` method is simply a function
which takes an input `io` and returns processed file(s) as output. Since it's
called for each upload, attaching the file will call it twice, first when
raw file is cached to temporary storage on assignment, then when cached file
is uploaded to permanent storage on saving. We usually want to process in the
latter phase (after file validations):

```rb
class ImageUploader < Shrine
  def process(io, context)
    if context[:phase] == :store
      # ...
    end
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

  def process(io, context)
    if context[:phase] == :store
      resize_to_limit(io.download, 700, 700)
    end
  end
end
```

Since here `io` is a cached `Shrine::UploadedFile`, we need to download it to
a file, as image_processing only accepts real files.

### Versions

If you're uploading images, often you'll want to store various thumbnails
alongside your original image. You can do that by loading the versions plugin,
and in `#process` simply returning a Hash of versions:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :versions

  def process(io, context)
    if context[:phase] == :store
      size_700 = resize_to_limit(io.download, 700, 700)
      size_500 = resize_to_limit(size_700,    500, 500)
      size_300 = resize_to_limit(size_500,    300, 300)

      {large: size_700, medium: size_500, small: size_300}
    end
  end
end
```

Being able to define processing on instance level provides a lot of flexibility,
allowing things like choosing the order or adding parallelization. It is
recommended to use the delete_raw plugin for automatically deleting processed
files after uploading.

The attachment getter will simply return the processed attachment as a Hash of
versions:

```rb
photo.image.class #=> Hash

# With the store_dimensions plugin
photo.image[:large].width  #=> 700
photo.image[:medium].width #=> 500
photo.image[:small].width  #=> 300

# The plugin expands this method to accept version names.
photo.image_url(:large) #=> "..."
```

## Context

You may have noticed the `context` variable as the second argument to
`Shrine#process`. This variable contains information about the context in
which the file is uploaded.

```rb
class ImageUploader < Shrine
  def process(io, context)
    puts context
  end
end
```
```rb
photo = Photo.new
photo.image = File.open("image.jpg") # "cache"
photo.save                           # "store"
```
```
{:name=>:image, :record=>#<Photo:0x007fe1627f1138>, :phase=>:cache}
{:name=>:image, :record=>#<Photo:0x007fe1627f1138>, :phase=>:store}
```

The `:name` is the name of the attachment, in this case "image". The `:record`
is the model instance, in this case instance of `Photo`. Lastly, the `:phase`
is a symbol which indicates the purpose of the upload (by default there are
only `:cache` and `:store`, but some plugins add more of them).

Context is useful for doing conditional processing and validation, since we
have access to the record and attachment name, and it is also used by some
plugins internally.

## Validations

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

You can also extract and store custom metadata by overriding
`Shrine#extract_metadata`:

```rb
class ImageUploader < Shrine
  def extract_metadata(io, context)
    metadata = super
    metadata["custom"] = extract_custom(io)
    metadata
  end
end
```

Note that you should always rewind the `io` after reading from it.

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

If you want to generate locations on your own, simply override
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

Note that there should always be a random component in the location, for dirty
tracking to be detected properly (you can use `Shrine#generate_uid`). Inside
`#generate_location` you can access the extracted metadata through
`context[:metadata]`.

When using the uploader directly, it's possible to bypass `#generate_location`
by passing a `:location`:

```rb
uploader = Shrine.new(:store)
file = File.open("nature.jpg")
uploader.upload(file, location: "some/specific/location.jpg")
```

## Storage

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
movie = Movie.new(video: File.open("video.mp4"))
movie.video_url #=> "/uploads/cache/j4k343ui12ls9.jpg"
movie.save
movie.video_url #=> "https://my-bucket.s3-eu-west-1.amazonaws.com/0943sf8gfk13.mp4"
```

If you're using S3 both for cache and store, uploading a cached file to store
will simply do an S3 COPY request instead of downloading and reuploading the
file. Also, the versions plugin takes advantage of S3's MULTI DELETE
capabilities, so versions are deleted with a single HTTP request.

See the full documentation for [FileSystem] and [S3] storages. There are also
many other Shrine storages available, see the [Plugins & Storages] section.

## Upload options

Many storages accept additional upload options, which you can pass via the
upload_options plugin, or manually when uploading:

```rb
uploader = Shrine.new(:store)
uploader.upload(file, upload_options: {acl: "private"})
```

## Direct uploads

Shrine comes with a direct_upload plugin which provides a [Roda] endpoint that
accepts file uploads. This allows you to asynchronously start caching the file
the moment the user selects it via AJAX (e.g. using the [jQuery-File-Upload] JS
library).

```rb
Shrine.plugin :direct_upload # Provides a Roda endpoint
```
```rb
Rails.application.routes.draw do
  mount VideoUploader::UploadEndpoint => "/attachments/videos"
end
```
```js
$('[type="file"]').fileupload({
  url:       '/attachments/videos/cache/upload',
  paramName: 'file',
  add:       function(e, data) { /* Disable the submit button */ },
  progress:  function(e, data) { /* Add a nice progress bar */ },
  done:      function(e, data) { /* Fill in the hidden field with the result */ }
});
```

The plugin also provides a route that can be used for doing direct S3 uploads.
See the documentation of the plugin for more details, as well as the
[Roda](https://github.com/janko-m/shrine-example)/[Rails](https://github.com/erikdahlstrand/shrine-rails-example)
example app which demonstrates multiple uploads directly to S3.

## Background jobs

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

The above puts all promoting (moving to store) and deleting of files into a
background Sidekiq job. Obviously instead of Sidekiq you can use any other
backgrounding library.

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

You will want to periodically clean your temporary storage. Amazon S3 provides
[a built-in solution](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html),
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

## Inspiration

Shrine was heavily inspired by [Refile] and [Roda]. From Refile it borrows the
idea of "backends" (here named "storages"), attachment interface, and direct
uploads. From Roda it borrows the implementation of an extensible [plugin
system].

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
[Plugins & Storages]: http://shrinerb.com#external
[`Shrine::UploadedFile`]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/Base/FileMethods.html
