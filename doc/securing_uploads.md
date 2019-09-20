# Securing uploads

Shrine does a lot to make your file uploads secure, but there are still a lot
of security measures that could be added by the user on the application's side.
This guide will try to cover some well-known security issues, ranging from the
obvious ones to not-so-obvious ones, and try to provide solutions.

## Validate file type

Almost always you will be accepting certain types of files, and it's a good
idea to create a whitelist (or a blacklist) of extensions and MIME types.

By default Shrine stores the MIME type derived from the extension, which means
it's not guaranteed to hold the actual MIME type of the the file. However, you
can load the `determine_mime_type` plugin to determine MIME type from magic
file headers.

```rb
# Gemfile
gem "marcel", "~> 0.3"
```
```rb
class MyUploader < Shrine
  plugin :determine_mime_type, analyzer: :marcel
  plugin :validation_helpers

  Attacher.validate do
    validate_extension %w[jpg jpeg png webp]
    validate_mime_type %w[image/jpeg image/png image/webp]
  end
end
```

## Limit filesize

It's a good idea to generally limit the filesize of uploaded files, so that
attackers cannot easily flood your storage. There are various layers at which
you can apply filesize limits, depending on how you're accepting uploads. For
starters you can add a filesize validation to prevent large files from being
uploaded to `:store`:

```rb
class MyUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 100*1024*1024 # 100 MB
  end
end
```

In the following sections we talk about various strategies to prevent files
from being uploaded to Shrine's temporary storage and the system's temporary
directory.

### Limiting filesize in direct uploads

If you're doing direct uploads with the `upload_endpoint` plugin, you can pass
in the `:max_size` option to reject files that are larger than the specified
limit:

```rb
plugin :upload_endpoint, max_size: 100*1024*1024 # 20 MB
```

If you're doing direct uploads to Amazon S3 using the `presign_endpoint`
plugin, you can pass in the `:content_length_range` presign option:

```rb
plugin :presign_endpoint, presign_options: -> (request) do
  { content_length_range: 0..100*1024*1024 }
end
```

### Limiting filesize at application level

If your application is accepting file uploads, it's good practice to limit the
maximum allowed `Content-Length` before calling `params` for the first time,
to avoid Rack parsing the multipart request parameters and creating a Tempfile
for uploads that are obviously attempts of attacks.

```rb
if request.content_length >= 100*1024*1024 # 100MB
  response.status = 413 # Request Entity Too Large
  response.body = "The uploaded file was too large (maximum is 100MB)"
  request.halt
end

request.params # Rack parses the multipart request params
```

Alternatively you can allow uploads of any size to temporary Shrine storage,
but tell Shrine to immediately delete the file if it failed validations by
loading the `remove_invalid` plugin.

```rb
plugin :remove_invalid
```

### Failsafe filesize limiting

If you want to make sure that no large files ever get to your storages, and you
don't really care about the error message, you can override `Shrine#upload`:

```rb
class MyUploader < Shrine
  def upload(io, **options)
    fail FileTooLarge if io.size >= 100*1024*1024

    super
  end
end
```

## Limit image dimensions

It's possible to create so-called [image bombs], which are images that have a
small filesize but very large dimensions. These are dangerous if you're doing
image processing, since processing them can take a lot of time and memory. This
makes it trivial to DoS the application which doesn't have any protection
against them.

So, in addition to validating filesize, we should also validate image
dimensions:

```rb
# Gemfile
gem "fastimage"
```
```rb
class ImageUploader < Shrine
  plugin :store_dimensions
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 100*1024*1024

    if validate_mime_type %w[image/jpeg image/png image/webp]
      validate_max_dimensions [5000, 5000]
    end
  end
end
```

If you want to be extra safe, you can add a failsafe before performing
processing:

```rb
class ImageUploader < Shrine
  # ...
  Attacher.derivatives_processor do |original|
    width, height = Shrine.dimensions(original)

    fail ImageBombError if width > 5000 || height > 5000

    # ...
  end
end
```

## Prevent metadata tampering

When cached file is retained on validation errors or it was direct uploaded,
the uploaded file representation is assigned to the attacher. This also
includes any file metadata. By default Shrine won't attempt to re-extract
metadata, because for remote storages that requires an additional HTTP request,
which might not be feasible depending on the application requirements.

However, this means that the attacker can directly upload a malicious file
(because direct uploads aren't validated), and then modify the metadata hash so
that it passes Shrine validations, before submitting the cached file to your
app. To guard yourself from such attacks, you can load the
`restore_cached_data` plugin, which will automatically re-extract metadata from
cached files on assignment and override the received metadata.

```rb
Shrine.plugin :restore_cached_data
```

## Limit number of files

When doing direct uploads, it's a good idea to apply some kind of throttling to
the endpoint, to ensure the attacker cannot upload an unlimited number files,
because even with a filesize limit it would allow flooding the storage. A good
library for throttling requests is [rack-attack].

Also, it's generally a good idea to limit the *minimum* filesize as well as
maximum, to prevent uploading large amounts of small files:

```rb
class MyUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_min_size 10*1024 # 10 KB
    # ...
  end
end
```

## References

* [Nvisium: Secure File Uploads](https://nvisium.com/blog/2015/10/13/secure-file-uploads/)
* [OWASP: Unrestricted File Upload](https://www.owasp.org/index.php/Unrestricted_File_Upload)
* [AppSec: 8 Basic Rules to Implement Secure File Uploads](https://software-security.sans.org/blog/2009/12/28/8-basic-rules-to-implement-secure-file-uploads/)

[image bombs]: https://www.bamsoftware.com/hacks/deflate.html
[rack-attack]: https://github.com/kickstarter/rack-attack
