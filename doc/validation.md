# File Validation

Shrine allows validating assigned files using the [`validation`][validation]
plugin. Validation code is defined inside an `Attacher.validate` block:

```rb
Shrine.plugin :validation
```
```rb
class ImageUploader < Shrine
  Attacher.validate do
    # ... perform validation ...
  end
end
```

The validation block is run when a new file is assigned, and any validation
errors are stored in `Shrine::Attacher#errors`. ORM plugins like `sequel` and
`activerecord` will automatically merge these validation errors into the
`#errors` hash on the model instance.

```rb
photo = Photo.new
photo.image = image_file
photo.valid? #=> false
photo.errors[:image] #=> [...]
```

## Validation helpers

The [`validation_helpers`][validation_helpers] plugin provides convenient
validators for built-in metadata:

```rb
Shrine.plugin :validation_helpers
```
```rb
class ImageUploader < Shrine
  Attacher.validate do
    validate_size      1..5*1024*1024
    validate_mime_type %w[image/jpeg image/png image/webp image/tiff]
    validate_extension %w[jpg jpeg png webp tiff tif]
  end
end
```

Note that for secure MIME type validation it's recommended to also load
`determine_mime_type` and `restore_cached_data` plugins.

See the [`validation_helpers`][validation_helpers] plugin documentation for
more details.

## Custom validations

You can also do your own custom validations:

```rb
# Gemfile
gem "streamio-ffmpeg"
```
```rb
require "streamio-ffmpeg"

class VideoUploader < Shrine
  plugin :add_metadata

  add_metadata :duration do |io|
    movie = Shrine.with_file(io) { |file| FFMPEG::Movie.new(file.path) }
    movie.duration
  end

  Attacher.validate do
    if file.duration > 5*60*60
      errors << "duration must not be longer than 5 hours"
    end
  end
end
```

## Inheritance

Validations are inherited from superclasses, but you need to call them manually
when defining more validations:

```rb
class ApplicationUploader < Shrine
  Attacher.validate { validate_max_size 5*1024*1024 }
end

class ImageUploader < ApplicationUploader
  Attacher.validate do
    super() # empty braces are required
    validate_mime_type %w[image/jpeg image/png image/webp]
  end
end
```

## Removing invalid files

By default, an invalid file will remain assigned after validation failed, but
you can have it automatically removed and deleted by loading the
`remove_invalid` plugin.

```rb
Shrine.plugin :remove_invalid # remove and delete files that failed validation
```

[validation]: /doc/plugins/validation.md#readme
[validation_helpers]: /doc/plugins/validation_helpers.md#readme
