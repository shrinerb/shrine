# Shrine

Shrine is a toolkit for file uploads in Ruby applications.

If you're new, you're encouraged to read the [introductory blog post] which
explains the motivation behind Shrine.

## Resources

* Documentation: [shrinerb.com](http://shrinerb.com)
* Source: [github.com/janko-m/shrine](https://github.com/janko-m/shrine)
* Bugs: [github.com/janko-m/shrine/issues](https://github.com/janko-m/shrine/issues)
* Help & Dicussion: [groups.google.com/group/ruby-shrine](https://groups.google.com/forum/#!forum/ruby-shrine)

## Installation

```rb
gem "shrine"
```

Shrine has been tested on MRI 2.1, MRI 2.2, JRuby and Rubinius.

## Basics

Here's a basic example showing how the file upload works in Shrine:

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages[:file_system] = Shrine::Storage::FileSystem.new("uploads")

uploader = Shrine.new(:file_system)

uploaded_file = uploader.upload(File.open("avatar.jpg"))
uploaded_file      #=> #<Shrine::UploadedFile>
uploaded_file.url  #=> "/uploads/9260ea09d8effd.jpg"
uploaded_file.data #=>
# {
#   "storage"  => "file_system",
#   "id"       => "9260ea09d8effd.jpg",
#   "metadata" => {...},
# }
```

First we add the storage we want to use to Shrine's registry. Storages are
simple Ruby classes which perform the actual uploads. We instantiate a `Shrine`
with the storage name, and when we call `#upload` Shrine does the following:

* generates a unique location for the file
* extracts metadata from the file
* uploads the file using the underlying storage
* closes the file
* returns a `Shrine::UploadedFile` with relevant data

The argument to `Shrine#upload` needs to be an IO-like object. So, `File`,
`Tempfile` and `StringIO` are all valid arguments. But the object doesn't have
to be an actual IO, it's enough that it responds to these 5 methods:
`#read(*args)`, `#size`, `#eof?`, `#rewind` and `#close`.
`ActionDispatch::Http::UploadedFile` is one such object.

The returned `Shrine::UploadedFile` represents the file that has been uploaded,
and we can do a lot with it:

```rb
uploaded_file.url      #=> "/uploads/938kjsdf932.jpg"
uploaded_file.read     #=> "..."
uploaded_file.exists?  #=> true
uploaded_file.download #=> #<Tempfile:/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/20151004-74201-1t2jacf>
uploaded_file.metadata #=> {...}
```

To read about the metadata that is stored with the uploaded file, see the
[metadata](#metadata) section. Once you're done with the file, you can delete
it.

```rb
uploaded_file.delete
```

## Attachment

In web applications, instead of managing files directly, we rather want to
treat them as "attachments" to recod tie them to their lifecycle. In Shrine we
do this by generating and including "attachment" modules.

Firstly we need to assign the special `:cache` and `:store` storages:

```rb
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", prefix: "uploads/cache"),
  store: Shrine::Storage::FileSystem.new("public", prefix: "uploads/store"),
}
```

These storages will by default be used for caching and storing attachments, but
you can use additional storages with the `default_storage` plugin. Next we
should create an uploader specific to the type of files we're uploading:

```rb
class ImageUploader < Shrine
  # logic for uploading images
end
```

Now if we assume that we have a "User" model, and we want our users to have an
"avatar", we can generate and include an "attachment" module:

```rb
class User
  attr_accessor :avatar_data

  include ImageUploader[:avatar]
end
```

Now our model has gained special methods for attaching avatars:

```rb
user = User.new
user.avatar = File.open("avatar.jpg") # uploads the file to cache
user.avatar      #=> #<Shrine::UploadedFile>
user.avatar_url  #=> "/uploads/9260ea09d8effd.jpg"
user.avatar_data #=> "{\"storage\":\"cache\",\"id\":\"9260ea09d8effd.jpg\",\"metadata\":{...}}"
```

The attachment module has added `#avatar`, `#avatar=` and `#avatar_url`
methods to our User. This is what's happening:

```rb
Shrine[:avatar] #=> #<Shrine::Attachment(avatar)>
Shrine[:avatar].is_a?(Module) #=> true
Shrine[:avatar].instance_methods #=> [:avatar=, :avatar, :avatar_url, :avatar_attacher]

Shrine[:document] #=> #<Shrine::Attachment(document)>
Shrine[:document].instance_methods #=> [:document=, :document, :document_url, :document_attacher]

# If you prefer to be more explicit, you can use the expanded forms
Shrine.attachment(:avatar)
Shrine::Attachment.new(:document)
```

The setter (`#avatar=`) caches the assigned file and writes it to the "data"
column (`avatar_data`). The getter (`#avatar`) reads the "data" column and
returns a `Shrine::UploadedFile`. The url method (`#avatar_url`) calls
`avatar.url` if the attachment is present, otherwise returns nil.

This is how you would typically create the form for a `@user`:

```erb
<form action="/users" method="post" enctype="multipart/form-data">
  <input name="user[avatar]" type="hidden" value="<%= @user.avatar_data %>">
  <input name="user[avatar]" type="file">
</form>
```

The "file" field is for file upload, while the "hidden" field is to make the
file persist in case of validation errors, and for direct uploads. This code
works because `#avatar=` also accepts already cached files via their JSON
representation:

```rb
user.avatar = '{"id":"9jsdf02kd", "storage":"cache", "metadata": {...}}'
```

### ORM

Your models probably won't be POROs, so Shrine ships with plugins for
Sequel and ActiveRecord ORMs. Shrine uses the `<attachment>_data` column
for storing attachments, so you'll need to add it in a migration:

```rb
add_column :users, :avatar_data, :text # or a JSON column
```
```rb
Shrine.plugin :sequel # or :activerecord
```
```rb
class User < Sequel::Model
  include ImageUploader[:avatar]
end
```

In addition to getters and setters, the ORM plugins add the appropriate
callbacks:

```rb
user.avatar = File.open("avatar.jpg")
user.avatar.storage_key #=> "cache"
user.save
user.avatar.storage_key #=> "store"
user.destroy
user.avatar.exists? #=> false
```

## Direct uploads

Shrine comes with a `direct_upload` plugin which provides a [Roda] endpoint
that can be used for AJAX uploads (using any JavaScript file upload library):

```rb
Shrine.plugin :direct_upload # Provides a Roda endpoint
```
```rb
Rails.application.routes.draw do
  mount ImageUploader::UploadEndpoint => "/attachments/images"
end
```
```rb
# POST /attachments/images/cache/avatar
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

The plugin also provides a route that can be used for doing direct S3 uploads,
see the documentation of the plugin for more details, as well as the [example
app] to see how easy it is to implement multiple uploads directly to S3.

## Processing

Whenever a file is uploaded, `Shrine#process` is called, and this is where
you're expected to define your processing.

```rb
class ImageUploader < Shrine
  def process(io, context)
    if context[:phase] == :store
      # processing...
    end
  end
end
```

The `io` is the file being uploaded, and `context` we'll leave for later.  You
may be wondering why we need this conditional. Well, when an attachment is
assigned and saved, an "upload" actually happens two times. First the file is
"uploaded" to cache on assignment, and then the cached file is reuploaded to
store on save.

Ok, now how do we do the actual processing? Well, Shrine actually doesn't ship
with any file processing functionality, because that is a generic problem that
belongs in a separate gem. If the type of files you're uploading are images, I
created the [image_processing] gem which you can use with Shrine:

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

Notice that we needed to call `io.download`. This is because the original file
was already stored to cache, and now this cached file is being uploaded to
store. The cached file is an instance of `Shrine::UploadedFile`, but for
processing we need to work with actual files, so we first need to download it.

In general, processing works in a way that if `#process` returns a file, Shrine
continues storing that file, otherwise if nil is returned, Shrine continues
storing the original file.

### Versions

If you're uploading images, often you'll want to store various thumbnails
alongside your original image. For that you just need to load the `versions`
plugin, and now in `#process` you can return a Hash of versions:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :versions, names: [:large, :medium, :small]

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

As you see, instead of a complex class-level DSL, Shrine provides a very simple
instance-level interface where you're in complete control over processing. The
processed files are Ruby Tempfiles and they should eventually get deleted by
themselves, but you can also use the `moving` plugin to delete them immediately
after upload.

Now when you access the stored attachment, a Hash of versions will be returned
instead:

```rb
user.avatar.class #=> Hash

# With the store_dimensions plugin
user.avatar[:large].width  #=> 700
user.avatar[:medium].width #=> 500
user.avatar[:small].width  #=> 300

# The plugin expands this method to accept version names.
user.avatar_url(:large) #=> "..."
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
user = User.new
user.avatar = File.open("avatar.jpg")  # "cache"
user.save                              # "store"
```
```
{:name=>:avatar, :record=>#<User:0x007fe1627f1138>, :phase=>:cache}
{:name=>:avatar, :record=>#<User:0x007fe1627f1138>, :phase=>:store}
```

The `:name` is the name of the attachment, in this case "avatar". The `:record`
is the model instance, in this case instance of `User`. As for `:phase`, in web
applications a file upload isn't an event that happens at once, it's a process
that happens in *phases*. By default there are only 2 phases, "cache" and
"store", other plugins add more of them.

Context is really useful for doing conditional processing and validation, since
we have access to the record and attachment name. In general the context is
used deeply in Shrine for various purposes.

## Validations

Validations are registered by calling `Shrine::Attacher.validate`, and are best
done with the `validation_helpers` plugin:

```rb
class DocumentUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    # Evaluated inside an instance of Shrine::Attacher.
    if record.guest?
      validate_max_size 10*1024*1024, message: "is too large (max is 10 MB)"
      validate_mime_type_inclusion ["application/pdf"]
    end
  end
end
```

```rb
user = User.new
user.resume = File.open("resume.pdf")
user.valid? #=> false
user.errors.to_hash #=> {resume: ["is too large (max is 2 MB)"]}
```

## Metadata

By default Shrine extracts and stores general file metadata:

```rb
class UsersController < ApplicationController
  def create
    user = User.create(params[:user])
    user.avatar.metadata #=>
    # {
    #   "filename"  => "my_avatar.jpg",
    #   "mime_type" => "image/jpeg",
    #   "size"      => 345993,
    # }

    user.avatar.original_filename #=> "my_avatar.jpg"
    user.avatar.mime_type         #=> "image/jpeg"
    user.avatar.size              #=> 345993
  end
end
```

### MIME type

By default, "mime_type" is inherited from `#content_type` of the uploaded file.
In case of Rails, this value is set from the `Content-Type` header, which the
browser sets solely based on the extension of the uploaded file. This means
that by default Shrine's "mime_type" is *not* guaranteed to hold the actual
MIME type of the file.

To help with that Shrine provides the `determine_mime_type` plugin, which by
default uses the UNIX [file] utility to determine the actual MIME type:

```rb
Shrine.plugin :determine_mime_type
```
```rb
user = User.create(avatar: File.open("image.mp4")) # image with a .mp4 extension
user.avatar.mime_type #=> "image/png"
```

### Dimensions

If you're uploading images and you want to store dimensions, you can use the
`store_dimensions` plugin which extracts dimensions using the [fastimage] gem.

```rb
ImageUploader.plugin :store_dimensions
```
```rb
user = User.create(avatar: File.open("image.jpg"))
user.avatar.width  #=> 400
user.avatar.height #=> 500
```

The fastimage gem has built-in protection against [image bombs].

### Custom metadata

You can also extract and store custom metadata, by overriding
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

## Locations

By default files will all be put in the same folder. If you want that each
attachment has its own directory, you can use the `pretty_location` plugin:

```rb
Shrine.plugin :pretty_location
```
```rb
user = User.create(avatar: File.open("avatar.jpg"))
user.avatar.id #=> "user/34/avatar/34krtreds2df.jpg"
```

If you want to generate your own locations, simply override
`Shrine#generate_location`:

```rb
class ImageUploader < Shrine
  def generate_location(io, context)
    "#{context[:record].class}/#{context[:record].id}/#{io.original_filename}"
  end
end
```

Note that in this case should make your locations unique, otherwise dirty
tracking won't be detected properly (you can use `Shrine#generate_uid`).

When using `Shrine` directly you can bypass `#generate_location` by passing in
`:location`

```rb
file = File.open("avatar.jpg")
Shrine.new(:store).upload(file, location: "some/specific/location.jpg")
```

## Storage

Other than [FileSystem], Shrine also ships with [S3] storage:

```rb
gem "aws-sdk", "~> 2.1"
```
```rb
require "shrine/storage/s3"

Shrine.storages[:store] = Shrine::Storage::S3.new(
  access_key_id:     "<ACCESS_KEY_ID>",      # "xyz"
  secret_access_key: "<SECRET_ACCESS_KEY>",  # "abc"
  region:            "<REGION>",             # "eu-west-1"
  bucket:            "<BUCKET>",             # "my-app"
)
```

```rb
user = User.new(avatar: File.open(:avatar))
user.avatar.url #=> "/uploads/j4k343ui12ls9.jpg"
user.save
user.avatar.url #=> "https://my-bucket.s3-eu-west-1.amazonaws.com/0943sf8gfk13.jpg"
```

If you're using S3 for both cache and store, saving the record will avoid
reuploading the file by issuing an S3 COPY command instead.  Also, the
`versions` plugin takes advantage of S3's MULTI DELETE capabilities, so
versions are deleted with a single HTTP request.

See the full documentation for [FileSystem] and [S3] storages. There are also
many other Shrine storages available, see the [Plugins & Storages] section.

### Clearing cache

You will want to periodically clean your cache storage. Amazon S3 provides [a
built-in solution](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html),
and for FileSystem you can put something like this in your Rake task:

```rb
file_system = Shrine.storages[:cache]
file_system.clear!(older_than: 1.week.ago) # adjust the time
```

## Background jobs

Shrine is the first uploading library designed from day one to be used with
background jobs. Backgrounding parts of file upload is essential for scaling
and good user experience, and Shrine provides a `backgrounding` plugin which
makes it really easy to plug in your backgrounding library:

```rb
Shrine.plugin :backgrounding
Shrine::Attacher.promote { |data| UploadJob.perform_async(data) }
Shrine::Attacher.delete { |data| DeleteJob.perform_async(data) }
```
```rb
class UploadJob
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
background Sidekiq job. Obviously instead of Sidekiq you can just as well use
any other backgrounding library.

The main advantages of Shrine's backgrounding support over other file upload
libraries are:

* **User experience** – After starting the background job, Shrine will save the
  record with the cached attachment so that it can be immediately shown to the
  user. With other file upload libraries users cannot see the file until the
  background job has finished, which is really lame.
* **Simplicity** – Instead of writing the workers for you, Shrine allows you
  to use your own workers in a very simple way. Also, no extra columns are
  required.
* **Generality** – The above solution will automatically work for all uploaders,
  types of files and models.
* **Safety** – All of Shrine's code has been designed to take delayed storing
  into account, so concurrency issues should be nonexistent.

## Plugins

Shrine comes with a small core which provides only the essential functionality,
and all additional features are available via plugins. This way you can choose
exactly how much Shrine does for you. Shrine itself [ships with over 35
plugins], most of them I haven't managed to cover here.

The plugin system respects inheritance, so you can choose which plugins will
be applied to which uploaders:

```rb
Shrine.plugin :logging # enables logging for all uploaders

class ImageUploader < Shrine
  plugin :store_dimensions # stores dimensions only for this uploader
end
```

## Inspiration

Shrine was heavily inspired by [Refile] and [Roda]. From Refile it borrows the
idea of "backends" (here named "storages"), attachment interface, and direct
uploads. From Roda it borrows the implementation of an extensible [plugin
system].

## How to Contribute

### Steps to set up dev environment

 1. Set RUBY_VERSION env variable.
 2. Set Ruby version and gemset using rvm, rbenv, etc. 
 3. Install ruby-filemagic. Instructions at: https://github.com/blackwinter/ruby-filemagic
 4. Run "bundle"
 5. Run "rake"

## License

The gem is available as open source under the terms of the [MIT License].

[Contributor Covenant]: http://contributor-covenant.org
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
