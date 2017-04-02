# Securing uploads

Shrine does a lot to make your file uploads secure, but there are still a lot
of security measures that could be added by the user on the application's side.
This guide will try to cover all the well-known security issues, ranging from
the obvious ones to not-so-obvious ones, and try to provide solutions.

## Validate file type

Almost always you will be accepting certain types of files, and it's a good
idea to create a whitelist (or a blacklist) of extensions and MIME types.

By default Shrine stores the MIME type derived from the extension, which means
it's not guaranteed to hold the actual MIME type of the the file. However, you
can load the `determine_mime_type` plugin which by default uses the [file]
utility to determine the MIME type from magic file headers.

```rb
class MyUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type

  Attacher.validate do
    validate_extension_inclusion %w[jpg jpeg png gif]
    validate_mime_type_inclusion %w[image/jpeg image/png image/gif]
  end
end
```

## Limit filesize

It's a good idea to generally limit the filesize of uploaded files, so that
attackers cannot easily flood your storage. There are various layers at which
you can apply filesize limits, depending on how you're accepting uploads.
Firstly, you should probably add a filesize validation to prevent large files
from being uploaded to `:store`:

```rb
class MyUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 20*1024*1024 # 20 MB
  end
end
```

In the following sections we talk about various strategies to prevent files from
being uploaded to cache and the temporary directory.

### Direct uploads

If you're doing direct uploads with the `direct_upload` plugin, you can pass
in the `:max_size` option, which will refuse too large files and automatically
delete it from temporary storage.

```rb
plugin :direct_upload, max_size: 20*1024*1024 # 20 MB
```

This option doesn't apply to presigned uploads, if you're using S3 you can
limit the filesize on presigning:

```rb
plugin :direct_upload, presign: ->(request) do
  {content_length_range: 0..20*1024*1024}
end
```

### Regular uploads

If you're simply accepting uploads synchronously in the form, you can prevent
large files from getting into cache by loading the `remove_invalid` plugin:

```rb
plugin :remove_invalid
```

### Limiting at application level

If your application is accepting file uploads directly (either through direct
uploads or regular ones), you can limit the maximum request body size in your
application server (nginx or apache):

```sh
# nginx.conf

http {
  # ...
  server {
    # ...
    client_max_body_size 20M;
  }
}
```

### Paranoid limiting

If you want to make sure that no large files ever get to your storages, and
you don't really care about the error message, you can use the `hooks` plugin
and raise an error:

```rb
class MyUploader
  plugin :hooks

  def before_upload(io, context)
    if io.respond_to?(:read)
      raise FileTooLarge if io.size >= 20*1024*1024
    end
  end
end
```

## Limit image dimensions

It's possible to create so-called [image bombs], which are images that have a
small filesize but very large dimensions. These are dangerous if you're doing
image processing, since processing them can take a lot of time and memory. This
makes it trivial to DoS the application which doesn't have any protection
against them.

Shrine uses the [fastimage] gem for determining image dimensions which has
built-in protection against image bombs (ImageMagick for example doesn't), but
you still need to prevent those files from being attached and processed:

```rb
class MyUploader < Shrine
  plugin :store_dimensions
  plugin :validation_helpers

  Attacher.validate do
    validate_max_width  2500
    validate_max_height 2500
  end
end
```

If you're doing processing on caching, you can use the fastimage gem directly
in a conditional.

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
  end
end
```

## References

* [Nvisium: Secure File Uploads](https://nvisium.com/blog/2015/10/13/secure-file-uploads/)
* [OWASP: Unrestricted File Upload](https://www.owasp.org/index.php/Unrestricted_File_Upload)
* [AppSec: 8 Basic Rules to Implement Secure File Uploads](https://software-security.sans.org/blog/2009/12/28/8-basic-rules-to-implement-secure-file-uploads/)

[image bombs]: https://www.bamsoftware.com/hacks/deflate.html
[fastimage]: https://github.com/sdsykes/fastimage
[file]: http://linux.die.net/man/1/file
[rack-attack]: https://github.com/kickstarter/rack-attack
