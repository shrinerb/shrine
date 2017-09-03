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

Add Shrine to the Gemfile and write an initializer which sets up the storage and
loads the ORM plugin:

```rb
# Gemfile
gem "shrine"
```

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"), # temporary
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"), # permanent
}

Shrine.plugin :sequel # or :activerecord
Shrine.plugin :cached_attachment_data # for forms
Shrine.plugin :rack_file # for non-Rails apps
```

Next decide how you will name the attachment attribute on your model, and run a
migration that adds an `<attachment>_data` text column, which Shrine will use
to store all information about the attachment:

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
uploaded file in case of validation errors and [direct uploads].

```erb
<form action="/photos" method="post" enctype="multipart/form-data">
  <input name="photo[image]" type="hidden" value="<%= @photo.cached_image_data %>">
  <input name="photo[image]" type="file">
</form>

<!-- ActionView::Helpers::FormHelper -->
<%= form_for @photo do |f| %>
  <%= f.hidden_field :image, value: @photo.cached_image_data %>
  <%= f.file_field :image %>
<% end %>

<!-- SimpleForm -->
<%= simple_form_for @photo do |f| %>
  <%= f.input :image, as: :hidden, input_html: {value: @photo.cached_image_data} %>
  <%= f.input :image, as: :file %>
<% end %>
```

Note that the file field needs to go *after* the hidden field, so that
selecting a new file can always override the cached file in the hidden field.
Also notice the `enctype="multipart/form-data"` HTML attribute, which is
required for submitting files through the form, though the Rails form builder
will automatically generate it for you.

Now in your router/controller the attachment request parameter can be assigned
to the model like any other attribute:

```rb
post "/photos" do
  Photo.create(params[:photo])
  # ...
end
```

Once a file is uploaded and attached to the record, you can retrieve a URL to
the uploaded file and display it:

```erb
<img src="<%= @photo.image_url %>">
```

## Storage

A "storage" in Shrine is an object responsible for managing files on a specific
storage service (filesystem, Amazon S3 etc), which implements a generic method
interface. Storages are configured directly and registered under a name in
`Shrine.storages`, so that they can be later used by uploaders.

```rb
# Gemfile
gem "aws-sdk-s3", "~> 1.2" # for Amazon S3 storage
```
```rb
require "shrine/storage/s3"

s3_options = {
  access_key_id:     "abc",
  secret_access_key: "xyz",
  region:            "my-region",
  bucket:            "my-bucket",
}

Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options),
  store: Shrine::Storage::S3.new(prefix: "store", **s3_options),
}
```

The above example sets up Amazon S3 storage both for temporary and permanent
storage, which allows for [direct uploads]. The `:cache` and `:store` names are
special only in terms that the attacher will automatically pick them up, but
you can also register more than two storages under different names.

Shrine ships with [FileSystem] and [S3] storage, take a look at their
documentation for more details on various features they support. There are also
[many more Shrine storages][external storages] shipping as external gems.

## Uploader

Uploaders are subclasses of `Shrine`, and are essentially wrappers around
storages. In addition to actually calling the underlying storage when they need
to, they also perform many generic tasks which aren't related to a particular
storage (like processing, extracting metadata, logging etc).

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
(image, video, audio, document etc), but you can structure them any way that
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
* closing the file

### IO abstraction

Shrine is able to upload any IO-like object that respond to `#read`, `#size`,
`#rewind`, `#eof?` and `#close`. This foremost includes all real IO objects
like File, Tempfile and StringIO.

When a file is uploaded to a Rails app, it will be represented by an
ActionDispatch::Http::UploadedFile object in the params. This is also an
IO-like object accepted by Shrine. In other Rack applications the uploaded file
will be represented as a Hash, but it can still be attached when [`rack_file`]
plugin is loaded.

Finally, the `Shrine::UploadedFile` object, returned by uploading, is itself an
IO-like object. This makes it incredibly easy to reupload a file from one
storage to another, and this is used by the attacher to reupload a file stored
on temporary storage to permanent storage.

### Deleting

The uploader can also delete uploaded files via `#delete`. Internally this just
delegates to the uploaded file, but some plugins bring additional behaviour
(e.g. logging).

```rb
uploaded_file = uploader.upload(file)
# ...
uploader.delete(uploaded_file)
```

## Uploaded file

The `Shrine::UploadedFile` object represents the file that was uploaded to the
storage. It contains the following information:

* `storage` – identifier of the storage the file was uploaded to
* `id` – the location of the file on the storage
* `metadata` – file metadata that was extracted during upload

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
uploaded_file.url      #=> "https://my-bucket.s3.amazonaws.com/949sdjg834.jpg"
uploaded_file.download #=> #<Tempfile>
uploaded_file.exists?  #=> true
uploaded_file.open { |io| io.read }
uploaded_file.delete
```

It also implements the IO-like interface that conforms to Shrine's IO
abstraction, which allows it to be uploaded to other storages.

```rb
uploaded_file.read   # returns content of the uploaded file
uploaded_file.eof?   # returns true if the whole IO was read
uploaded_file.rewind # rewinds the IO
uploaded_file.close  # closes the IO
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

You can choose whichever of these three syntaxes you prefer. In any case this
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

If there is already a file attached, and the attachment is overriden (either
with a new file or no file), the previous attachment will get deleted when the
record gets saved.

```rb
photo.update(image: new_file) # changes the attachment and deletes previous
# or
photo.update(image: nil)      # removes the attachment and deletes previous
```

In addition to assigning raw files, you can also assign a JSON representation
of files that are already uploaded to the temporary storage. This allows Shrine
to retain cached files in case of validation errors, and handle [direct
uploads], via the hidden form field.

```rb
photo.image = '{
  "id": "9260ea09d8effd.jpg",
  "storage": "cache",
  "metadata": { ... }
}'
```

## Attacher

The model attachment attributes and callbacks just delegate the behaviour
to a `Shrine::Attacher` object.

```rb
attacher = ImageUploader::Attacher.new(photo, :image) # returned by `photo.image_attacher`

attacher.assign(file) # equivalent to `photo.image = file`
attacher.get          # equivalent to `photo.image`
attacher.url          # equivalent to `photo.image_url`
```

The attacher is what drives attaching files to models, and it functions
independently from models' attachment interface. This means that you can use it
as an alternative, in case you prefer not to add additional attributes to the
model, or prefer explicitness over callbacks. It's also useful when you need
something more advanced which isn't available through the attachment
attributes.

Whenever the attacher uploads or deletes files, it sends a `context` hash
which includes `:record`, `:name`, and `:action` keys, so that you can perform
processing or generate location differently depending on this information. See
[Context] section for more details.

For more information about `Shrine::Attacher`, see [Using Attacher] guide.

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

## Metadata

Shrine automatically extracts available file metadata and saves them to the
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

By default "mime_type" will be inherited from `#content_type` of the uploaded
file, which is set from the "Content-Type" request header, but this header is
determined by the browser solely based on the file extension. This means that
by default Shrine's "mime_type" is **not guaranteed** to hold the actual MIME
type of the file.

However, if you load the `determine_mime_type` plugin, that will make Shrine
always extract the MIME type from **file content**.

```rb
Shrine.plugin :determine_mime_type
```
```rb
File.write("image.png", "<?php ... ?>") # PHP file with a .png extension
photo = Photo.create(image: File.open("image.png"))
photo.image.mime_type #=> "text/x-php"
```

By the default the UNIX [`file`] utility is used, but you can also choose a
different analyzer, see plugin's documentation for more details.

### Custom metadata

In addition to the built-in metadata, you can also extract and store completely
custom metadata with the `add_metadata` plugin. For example, if we're uploading
videos, we could store additional video-specific metadata:

```rb
require "streamio-ffmpeg"

class VideoUploader < Shrine
  plugin :add_metadata

  add_metadata do |io, context|
    movie = FFMPEG::Movie.new(io.path)

    { "duration"   => movie.duration,
      "bitrate"    => movie.bitrate,
      "resolution" => movie.resolution,
      "frame_rate" => movie.frame_rate }
  end
end
```
```rb
video.metadata["duration"]   #=> 7.5
video.metadata["bitrate"]    #=> 481
video.metadata["resolution"] #=> "640x480"
video.metadata["frame_rate"] #=> 16.72
```

## Processing

You can have Shrine perform file processing before uploading to storage. It's
generally best to process files prior to uploading to permanent storage,
because at that point the selected file has been succesfully validated, and
this part can be moved into a background job.

This promote phase is called `:store`, and we can use the `processing` plugin
to define processing for that phase:

```rb
class ImageUploader < Shrine
  plugin :processing

  process(:store) do |io, context|
    # ...
  end
end
```

Now, how do we do the actual processing? Well, Shrine actually doesn't ship
with any file processing functionality, because that is a generic problem that
belongs in separate libraries. If the type of files you're uploading are
images, I created the [image_processing] gem which you can use with Shrine:

```rb
# Gemfile
gem "image_processing"
gem "mini_magick", ">= 4.3.5"
```
```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :processing

  process(:store) do |io, context|
    resize_to_limit!(io.download, 800, 800) { |cmd| cmd.auto_orient } # orient rotated images
  end
end
```

Here the `io` is a cached `Shrine::UploadedFile`, so we need to download it to
a file, since file processing tools usually work with files on the filesystem.

Shrine treats file processing as a functional transformation; you are given the
original file, and how you're going to perform processing is entirely up to
you, you only need to return the processed files at the end of the block. Then
instead of uploading the original file, Shrine will continue to upload the
files that the processing block returned.

### Versions

Sometimes we want to generate multiple files as the result of processing. If
we're uploading images, we might want to store various thumbnails alongside the
original image. If we're uploading videos, we might want to save screenshots
or transcode the video into different formats.

To be able to save multiple files, we just need to load the `versions` plugin,
and then in processing block we can return a Hash of files. It is recommended
to also load the `delete_raw` plugin, so that processed files are automatically
deleted after uploading.

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :processing
  plugin :versions   # enable Shrine to handle a hash of files
  plugin :delete_raw # delete processed files after uploading

  process(:store) do |io, context|
    original = io.download

    size_800 = resize_to_limit!(original, 800, 800) { |cmd| cmd.auto_orient } # orient rotated images
    size_500 = resize_to_limit(size_800,  500, 500)
    size_300 = resize_to_limit(size_500,  300, 300)

    {original: io, large: size_800, medium: size_500, small: size_300}
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
photo.image_url(:large) #=> "..."
```

### Custom processing

Your processing tool doesn't have to be in any way designed for Shrine
([image_processing] that we saw earlier is a generic library), the only thing
that you need to do is return processed files as some kind of IO objects. Here
is an example of transcoding a video using [ffmpeg]:

```rb
require "streamio-ffmpeg"

class VideoUploader < Shrine
  plugin :processing
  plugin :versions
  plugin :delete_raw

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

The `#upload` (and `#delete`) methods accept a hash of options as the second
argument, which is forwarded to all other tasks like processing, extracting
metadata and generating location.

```rb
uploader.upload(file, {foo: "bar"}) # context hash is forwarded to all tasks around upload
```

Some options are actually recognized by Shrine, like `:location` and
`:upload_options`, and some are added by plugins. However, most options are
there just to provide you context, for more flexibility in performing tasks and
better logging.

The attacher automatically includes additional `context` information for each
upload and delete:

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
validations are registered inside a `Attacher.validate` block, and you can load
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
user.errors.to_hash #=> {cv: ["is too large (max is 5 MB)"]}
```

You can also do custom validations:

```rb
class DocumentUploader < Shrine
  Attacher.validate do
    errors << "has more than 3 pages" if get.metadata["pages"] > 3
  end
end
```

When file validations fail, Shrine will by default keep the invalid cached file
assigned to the model instance. If you want the invalid file to be deassigned,
you can load the `remove_invalid` plugin.

The `Attacher.validate` block is executed in context of a `Shrine::Attacher`
instance:

```rb
class DocumentUploader < Shrine
  Attacher.validate do
    self   #=> #<Shrine::Attacher>

    get    #=> #<Shrine::UploadedFile>
    record #=> #<User>
    name   #=> :cv
  end
end
```

Validations are inherited from superclasses, but you need to call them manually
when defining more validations:

```ruby
class ApplicationUploader < Shrine
  Attacher.validate { validate_max_size 5.megabytes }
end

class ImageUploader < ApplicationUploader
  Attacher.validate do
    super() # empty braces are required
    validate_mime_type_inclusion %w[image/jpeg image/jpg image/png]
  end
end
```

## Location

Before Shrine uploads a file, it generates a random location for it. By default
the hierarchy is flat; all files are stored in the root directory of the
storage. You can change how the location is generated by overriding
`#generate_location`:

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
any ORM dirty tracking is detected properly. Inside `#generate_location` you
can also access the extracted metadata through `context[:metadata]`.

When uploading single files, it's possible to bypass `#generate_location` via
the uploader, by specifying `:location`:

```rb
uploader.upload(file, location: "some/specific/location.mp4")
```

## Direct uploads

While having files uploaded on form submit is simplest to implement, it doesn't
provide the best user experience, because the user doesn't know how long they
need to wait for the file to get uploaded.

To improve the user experience, the application can actually start uploading
the file **asynchronously** already when it has been selected, and provide a
progress bar. This way the user can estimate when the upload is going to
finish, and they can continue filling in other fields in the form while the
file is being uploaded.

Shrine comes with the `upload_endpoint` plugin, which provides a Rack endpoint
that accepts file uploads and forwards them to specified storage. We want to
set it up to upload to *temporary* storage, because we're replacing the caching
step in the default synchronous workflow.

```rb
Shrine.plugin :upload_endpoint
```
```rb
Rails.application.routes.draw do
  mount ImageUploader.upload_endpoint(:cache) => "/images/upload"
end
```

The above created a `POST /images/upload` endpoint. You can now use a
client-side file upload library like [FineUploader], [Dropzone] or
[jQuery-File-Upload] to upload files asynchronously to the `/images/upload`
endpoint the moment they are selected. Once the file has been uploaded, the
endpoint will return JSON data of the uploaded file, which the client can then
write to a hidden attachment field, to be submitted instead of the raw file.

Many popular storage services can accept file uploads directly from the client
([Amazon S3], [Google Cloud Storage], [Microsoft Azure Storage] etc), which
means you can avoid uploading files through your app. If you're using one of
these storage services, you can use the `presign_endpoint` plugin to generate
URL, fields, and headers that can be used to upload files directly to the
storage service. The only difference from the `upload_endpoint` workflow is
that the client has the extra step of fetching the request information before
uploading the file.

See the [upload_endpoint] and [presign_endpoint] plugin documentations and
[Direct Uploads to S3][direct uploads] guide for more details, as well as the
[Roda][roda_demo] and [Rails][rails_demo] demo apps which implement multiple
uploads directly to S3.

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

The above puts all promoting (uploading cached file to permanent storage) and
deleting of files into background jobs using Sidekiq. Obviously instead of
Sidekiq you can use [any other backgrounding library][backgrounding libraries].

The main advantages of Shrine's backgrounding support over other file attachment
libraries are:

* **User experience** – Before starting the background job, Shrine will save the
  record with the cached attachment so that it can be immediately shown to the
  user. With other file upload libraries users cannot see the file until the
  background job has finished.
* **Simplicity** – Instead of shipping with workers for you, Shrine allows you
  to write your own workers and plug them in very easily. And no extra
  columns are required.
* **Generality** – This setup will automatically be used for all uploaders,
  types of files and models.
* **Safety** – All of Shrine's features have been designed to take delayed
  storing into account, and concurrent requests are handled as well.

## Clearing cache

From time to time you'll want to clean your temporary storage from old files.
Amazon S3 provides [a built-in solution][S3 lifecycle], and for FileSystem you
can run something like this periodically:

```rb
file_system = Shrine.storages[:cache]
file_system.clear!(older_than: Time.now - 7*24*60*60) # delete files older than 1 week
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
closed or the device are shut down. You can use a client library like
[tus-js-client] to upload the file to [tus-ruby-server], and attach the
uploaded file to a record using [shrine-url]. See [shrine-tus-demo] for an
example of complete implementation.

Another option might be to do chunked uploads directly to your storage service,
if the storage service supports it (e.g. Amazon S3 or Google Cloud Storage).

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

## Code of Conduct

Everyone interacting in the Shrine project’s codebases, issue trackers, and
mailing lists is expected to follow the [Shrine code of conduct][CoC].

## License

The gem is available as open source under the terms of the [MIT License].

[motivation]: https://twin.github.io/better-file-uploads-with-shrine-motivation/
[FileSystem]: http://shrinerb.com/rdoc/classes/Shrine/Storage/FileSystem.html
[S3]: http://shrinerb.com/rdoc/classes/Shrine/Storage/S3.html
[direct uploads]: http://shrinerb.com/rdoc/files/doc/direct_s3_md.html
[external storages]: http://shrinerb.com/#external
[`rack_file`]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/RackFile.html
[Using Attacher]: http://shrinerb.com/rdoc/files/doc/attacher_md.html
[plugins]: http://shrinerb.com/#plugins
[`file`]: http://linux.die.net/man/1/file
[backgrounding]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/Backgrounding.html
[Context]: https://github.com/janko-m/shrine#context
[image_processing]: https://github.com/janko-m/image_processing
[ffmpeg]: https://github.com/streamio/streamio-ffmpeg
[FineUploader]: https://github.com/FineUploader/fine-uploader
[Dropzone]: https://github.com/enyo/dropzone
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
[Amazon S3]: https://aws.amazon.com/s3/
[Google Cloud Storage]: https://cloud.google.com/storage/
[Microsoft Azure Storage]: https://azure.microsoft.com/en-us/services/storage/
[upload_endpoint]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/UploadEndpoint.html
[presign_endpoint]: http://shrinerb.com/rdoc/classes/Shrine/Plugins/PresignEndpoint.html
[Cloudinary]: https://github.com/janko-m/shrine-cloudinary
[Imgix]: https://github.com/janko-m/shrine-imgix
[Uploadcare]: https://github.com/janko-m/shrine-uploadcare
[Attache]: https://github.com/choonkeat/attache
[Dragonfly]: http://markevans.github.io/dragonfly/
[tus]: http://tus.io
[tus-ruby-server]: https://github.com/janko-m/tus-ruby-server
[tus-js-client]: https://github.com/tus/tus-js-client
[shrine-tus-demo]: https://github.com/janko-m/shrine-tus-demo
[shrine-url]: https://github.com/janko-m/shrine-url
[Roda]: https://github.com/jeremyevans/roda
[Refile]: https://github.com/refile/refile
[MIT License]: http://opensource.org/licenses/MIT
[CoC]: https://github.com/janko-m/shrine/blob/master/CODE_OF_CONDUCT.md
[roda_demo]: https://github.com/janko-m/shrine/tree/master/demo
[rails_demo]: https://github.com/erikdahlstrand/shrine-rails-example
[backgrounding libraries]: https://github.com/janko-m/shrine/wiki/Backgrounding-libraries
[S3 lifecycle]: http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html
