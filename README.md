# Shrine

Shrine is a toolkit for file uploads in Ruby.

## Installation

```rb
gem "shrine"
```

## Basics

```rb
require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {file_system: Shrine::Storage::FileSystem.new("uploads")}

uploader = Shrine.new(:file_system)

uploaded_file = uploader.upload(File.open("avatar.jpg"))
uploaded_file      #=> #<Shrine::UploadedFile>
uploaded_file.url  #=> "uploads/9260ea09d8effd.jpg"
uploaded_file.data #=>
# {
#   "storage"  => "file_system",
#   "id"       => "9260ea09d8effd.jpg",
#   "metadata" => {...},
# }
```

First we add the storage we want to use to Shrine's registry. Storages are
simply Ruby classes which perform the actual uploads. We instantiate a `Shrine`
instance which wraps the storage, and when we call `Shrine#upload` the
following happens:

* a unique location is generated for the file
* metadata is extracted from the file
* the underlying storage is called to store the file
* a `Shrine::UploadedFile` is returned with data filled in

The argument to `Shrine#upload` needs to be an IO object. So `File`, `Tempfile`
and `StringIO` are all valid arguments. But the object doesn't have to be an
actual IO, it's enough that it responds to these 5 methods: `#read(*args)`,
`#size`, `#eof?`, `#rewind` and `#close`.  `ActionDispatch::Http::UploadedFile`
is one such object, but you can also make your own.

You can now download the uploaded file from the storage:

```rb
file = uploaded_file.download
file #=> #<Tempfile:/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/20151004-74201-1t2jacf>
```

When you're done, you can delete the file:

```rb
uploader.delete(uploaded_file)
uploaded_file.exists? #=> false
```

## Attachment

Ok, so far we've seen the low-level interface, which is very useful when you
need to work with files directly, but isn't that convenient when you want to
attach these files to models.  For that Shrine provides a high-level interface
using "attachment" modules.

Firstly we need to assign the special `:cache` and `:store` storages:

```rb
Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new(Dir.tmpdir),
  store: Shrine::Storage::FileSystem.new("public", subdirectory: "uploads"),
}
```

Next we should create an uploader specific to the type of files we're
uploading:

```rb
class ImageUploader < Shrine
  # here goes your uploading logic
end
```

Now if we for example want our Users to have avatars, we can generate and
include an "avatar" attachment module:

```rb
class User
  attr_accessor :avatar_data

  include ImageUploader[:avatar]
end
```
```rb
user = User.new
user.avatar = File.open("avatar.jpg") # uploads the file to `:cache`
user.avatar      #=> #<Shrine::UploadedFile>
user.avatar_url  #=> "/uploads/9260ea09d8effd.jpg"
user.avatar_data #=>
# {
#   "storage"  => "cache",
#   "id"       => "9260ea09d8effd.jpg",
#   "metadata" => {...},
# }
```

Notice that the attachment module added `#avatar`, `#avatar=` and `#avatar_url`
methods to User. `ImageUploader[:avatar]` generated a module with these
methods, which when included to our User model.

```rb
Shrine[:avatar] #=> #<Shrine::Attachment(avatar)>
Shrine[:avatar].class #=> Module
Shrine[:avatar].instance_methods #=> [:avatar=, :avatar, :avatar_url, ...]

Shrine[:document] #=> #<Shrine::Attachment(document)>
Shrine[:document].instance_methods #=> [:document=, :document, :document_url, ...]

# If you prefer to be more explicit, you can use the expanded forms
Shrine.attachment(:avatar)
Shrine::Attachment.new(:document)
```

The setter (`#avatar=`) caches the assigned file and writes it to the "data"
column (`avatar_data`). The getter (`#avatar`) reads the "data" column and
returns a `Shrine::UploadedFile`. The url method (`#avatar_url`) calls
`avatar.url` if the attachment is present, otherwise returns nil.

### ORM

Your models probably won't be POROs, so Shrine ships with plugins for
ActiveRecord and Sequel ORMs. First, we need to add a "data" column for our
attachment:

```rb
add_column :users, :avatar_data, :text
```
```rb
Shrine.plugin :activerecord
```
```rb
class User < ActiveRecord::Base
  include ImageUploader[:avatar]
end
```

Along with getters and setters, this now also adds appropriate
`before/after_save` and `after_destroy` hooks:

```rb
user.avatar = File.open("avatar.jpg")
user.avatar.storage_key #=> "cache"
user.save
user.avatar.storage_key #=> "store"
user.destroy
user.avatar.exists? #=> false
```

In Rails this is how you would typically create the form for a `@user`:

```erb
<%= form_for @user do |f| %>
  <%= f.hidden_field :avatar, value: @user.avatar_data %>
  <%= f.file_field :avatar %>
<% end %>
```

The `file_field` is for file upload, and the `hidden_field` is to make the
file persist in case of validation errors.

## Direct uploads

Shrine comes with a `direct_upload` plugin which provides an endpoint
(implemented in [Roda]) that can be used for AJAX uploads.

```rb
Shrine.plugin :direct_upload
```
```rb
Rails.application.routes.draw do
  # adds a `POST /attachments/images/:storage/:name` route
  mount ImageUploader.direct_endpoint => "/attachments/images"
end
```
```sh
$ curl -F "file=@/path/to/avatar.jpg" localhost:3000/attachments/images/cache/avatar
# {"id":"43kewit94.jpg","storage":"cache","metadata":{...}}
```

There are many great JavaScript libraries for AJAX file uploads, for example
this is how we could use [jQuery-File-Upload] for direct uploads to our endpoint:

```js
$('[type="file"]').fileupload({
  url '/attachments/images/cache/avatar',
  paramName: 'file', // we send the file in a "file" query parameter
  done: function(e, data) { $(this).prev().value(data.result) }
});
```

## Processing

Whenever a file is uploaded, `Shrine#process` is called, and this is where
you're expected to define your processing.

```rb
class ImageUploader < Shrine
  def process(io, context)
    if storage_key == :store
      # processing...
    end
  end
end
```
```rb
class User < ActiveRecord::Base
  include ImageUploader[:avatar]
end
```

The `io` is the file being uploaded, and `context` we'll leave for later.  You
may be wondering why we need this conditional. Well, when an attachment is
assigned and saved, an "upload" actually happens two times. Firstly the file
is "uploaded" to `:cache` on assignment, and then the cached file is reuploaded
to `:store` on save.

Now that we got that out of the way, how do we do the actual processing? Well,
Shrine actually doesn't ship with any image processing functionality, because
that is a generic problem that belongs in a separate gem. So, I created the
[image_processing] gem which you can use with Shrine:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick

  def process(io, context)
    if storage_key == :store
      process_to_limit!(io.download, 700, 700)
    end
  end
end
```

Notice that we needed to call `io.download`. This is because the original file
was already stored to `:cache`, and now this cached file is being uploaded to
`:store`. The cached file is an instance of `Shrine::UploadedFile`, but for
processing we need to work with actual files, so we first need to download it.

Keep in mind that `Shrine::UploadedFile` respresents a file uploaded to an
abstract storage. Even though `Shrine::Storage::FileSystem` happens to store
its files on disk, we still pretend that we `#download` it to respect the
abstraction.

In general, processing works in a way that if `#process` returns a file, Shrine
assumes that this is a processed file and continues storing that file.  If
`#process` however returns nil, that signals to Shrine to continue uploading
the original file.

### Versions

Often you'll want to also store various thumbnails alongside your original
image. Shrine's `versions` plugin introduces your uploader to the concept of
versions, and gives you the ability to return a Hash in `Shrine#process`:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  include ImageProcessing::MiniMagick
  plugin :versions, names: [:large, :medium, :small]

  def process(io, context)
    if storage_key == :store
      size_700 = process_to_limit!(io.download, 700, 700)
      size_500 = process_to_limit!(size_700,    500, 500)
      size_300 = process_to_limit!(size_500,    300, 300)

      {large: size_700, medium: size_500, small: size_300}
    end
  end
end
```

As you see, instead of a complex class-level DSL, Shrine provides a very simple
instance-level interface where you're in complete control over processing.  The
processed files are Ruby's Tempfiles, so they should eventually get deleted by
themselves. But if you're concerned about this, you can use the `moving`
plugin, which will delete the processed files as soon as they're uploaded.

Now when you access your stored attachments, a Hash of versions will be
returned instead:

```rb
user.avatar #=>
# {
#   large:  #<Shrine::UploadedFile>,
#   medium: #<Shrine::UploadedFile>,
#   small:  #<Shrine::UploadedFile>,
# }
user.avatar.class #=> Hash

# With the store_dimensions plugin
user.avatar[:large].width  #=> 700
user.avatar[:medium].width #=> 500
user.avatar[:small].width  #=> 300

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
user.avatar = File.open("avatar.jpg")  # "assign"
user.save                              # "promote"
```
```
{:name=>:avatar, :record=>#<User:0x007fe1627f1138>, :phase=>:assign}
{:name=>:avatar, :record=>#<User:0x007fe1627f1138>, :phase=>:promote}
```

The `:name` is the name of the attachment, in this case "avatar". The `:record`
is the model instance, in this case a `User`. As for `:phase`, in web
applications a file upload isn't an event that happens at once, it's a process
that happens in *phases*. The base functionality only has 2 phases, "assign"
and "promote", but there are plugins which add more of them.

Context is really useful for doing conditional processing and validations based
on the name of the attachment and column values. In general the context is
saturated through the whole stack and is used by a lot of plugins.

## Validations

Validations are registered by calling `Shrine::Attacher.validate`, and are best
done with the `validation_helpers` plugin:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    # Evaluated inside an instance of Shrine::Attacher.
    if record.guest?
      validate_max_size 2.megabytes, message: "is too large (max is 2 MB)"
    end
  end
end

class User < ActiveRecord::Base
  include ImageUploader[:avatar]
end

user = User.new(avatar: File.open("big_image.jpg"))
user.valid? #=> false
user.errors.to_hash #=> {avatar: ["is too large (max is 2 MB)"]}
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

To help with that Shrine provides the `extract_mime_type` plugin, which by
deafult uses the UNIX [file] utility to determine the actual MIME type:

```rb
ImageUploader.plugin :extract_mime_type

user = User.create(avatar: File.open("image.mp4")) # image with a .mp4 extension
user.avatar.mime_type #=> "image/png"
```

### Dimensions

Shrine ships with the `store_dimensions` plugin which extracts dimensions
using the [fastimage] gem.

```rb
ImageUploader.plugin :store_dimensions

user = User.create(avatar: File.open("image.jpg"))
user.avatar.width  #=> 400
user.avatar.height #=> 500
```

The fastimage gem has built-in protection against [image bombs].

## Default URL

When attachment is missing, `user.avatar_url` by default returns nil. This
because it internally calls `Shrine#default_url`, which returns nil unless
overriden. For custom default URLs simply override the method:

```rb
class ImageUploader < Shrine
  def default_url(context)
    "/images/fallback/#{context[:name]}.png"
  end
end
```

## Locations

By default files will all be put in the same folder. If you want that each
record has its own directory, you can use the `pretty_location` plugin:

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
    # your custom logic
  end
end
```

Note that the location should always be unique, otherwise dirty tracking won't
be detected properly (you can use `Shrine#generate_uid`).

When you're using `Shrine` directly, if you want to upload a file to a specific
location, you can pass the `:location` parameter (which bypasses
`#generate_location`):

```rb
file = File.open("avatar.jpg")
Shrine.new(:store).upload(file, location: "a/specific/location.jpg")
```

## Amazon S3

So far in the examples we've only used the FileSystem storage. However, Shrine
also ships with S3 storage, which internally uses the [aws-sdk] gem.

```
gem "aws-sdk", "~> 2.1"
```

It's typically good to use FileSystem for `:cache`, and S3 for `:store`:

```rb
require "shrine"
require "shrine/storage/file_system"
require "shrine/storage/s3"

s3_options = {
  access_key_id:     "<ACCESS_KEY_ID>",      # "xyz"
  secret_access_key: "<SECRET_ACCESS_KEY>",  # "abc"
  region:            "<REGION>",             # "eu-west-1"
  bucket:            "<BUCKET>",             # "my-app"
}

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("public", subdirectory: "uploads"),
  store: Shrine::Storage::S3.new(s3_options),
}
```

```rb
user = User.new(avatar: File.open(:avatar))
user.avatar.url #=> "/uploads/j4k343ui12ls9.jpg"
user.save
user.avatar.url #=> "https://s3-sa-east-1.amazonaws.com/my-bucket/0943sf8gfk13.jpg"
```

If you're using S3 for both `:cache` and `:store`, saving the record will
execute an S3 COPY command if possible, which avoids reuploading the file.
Also, the `versions` plugin uses S3's MULTI DELETE capabilities, so versions
are deleted with a single HTTP request.

## Background jobs

Shrine doesn't ship with an out-of-the-box solution for background jobs, but
it's designed in a way to make it as easy as possible. Here's an example how
you could implement background promoting with Sidekiq:

```rb
class ImageUploader < Shrine
  plugin :background_helpers

  Attacher.promote do |cached_file|
    # Evaluated inside an instance of Shrine::Attacher.
    UploadWorker.perform_async(cached_file, record.class, record.id, name)
  end
end
```
```rb
class UploadWorker
  include Sidekiq::Worker

  def perform(cached_file_json, record_class, record_id, name)
    record = Object.const_get(record_class).find(record_id)
    attacher = record.send("#{name}_attacher")
    cached_file = attacher.uploaded_file(cached_file_json)

    attacher.promote(cached_file)
    record.save
  end
end
```

Not the complicated, is it? This actually works surprisingly well, I would even
argue that it works better than any existing "out-of-the-box" solution for
other uploading libraries.

### Seamless user experience

After the user submits the form, promoting will be kicked off into a background
job, and the record will be saved with the cached image. This means that, if
you have your `:cache` in the "public" folder, the end user will be able to
immediately see their uploaded file, because the URL will point to the cached
version.

In the meanwhile, what `#promote` does is it uploads the cached file `:store`,
and writes the stored file to the column. When the record gets saved, the end
user won't even notice that the URL has updated from filesystem to S3, because
they still see the same image.

### Generality

This worker is completely agnostic about what kind of attachment it is
uploading, and for which model. This means that if you ever add different
attachments to other models, you can still use the same worker for all the
promoting.

### Safety

It is possible that the user changes their mind and reuploads a new file, but
before the background job finished promoting.  This can happen either if the
user was too quick, or the background job was too slow.

Normally what would happen in that case is that the old job would finish
running, and replace the new file with the old one. At the end it would
probably turn out fine, because the job that's running for the new attachment
would eventually replace the old one again. However, there would be a period
where the user would see an old image *after* they uploaded a new one, which
can be upsetting.

Shrine handles this gracefully. After `#promote` uploads the cached file to
`:store`, it checks if the cached file still matches the file in the record
column. If the files are different, that means the user reuploaded the
attachment, and Shrine won't do the replacement. Additionally, this job is
idempotent, meaning it can be safely repeated in case of failure.

## Clearing cache

Your `:cache` storage will grow over time, so you'll want to periodically clean
it. If you're using FileSystem as your `:cache`, you can put this in a
scheduled job:

```rb
file_system = Shrine.storages[:cache]
file_system.clear!(older_than: 1.week.ago) # adjust the time
```

If your `:cache` is S3, Amazon provides settings for automatic cache clearing,
see [this article](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html).

## Plugins

Shrine has a small core which provides only the essential functionality.
However, it comes with a lot of additional features which can be loaded via
plugins. This way you can choose exactly how much Shrine does for you. Shrine
itself ships with over 20 plugins, but it's also easy to create your own ([see
the guide](...)).

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
idea of "backends" (here named "storages"), and the high-level idea of the
attachment interface. From Roda it borrows the implementation of an extensible
[plugin system].

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
