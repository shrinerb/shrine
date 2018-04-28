# File Validation

Shrine allows validating assigned files based on their metadata. Validation
code is defined inside a `Shrine::Attacher.validate` block:

```rb
class ImageUploader < Shrine
  Attacher.validate do
    # validations
  end
end
```

The validation block is run when a file is assigned to an attachment attribute,
afterwards the validation errors are stored in `Shrine::Attacher#errors`. ORM
plugins like `sequel` and `activerecord` will automatically merge these
validation errors into the `#errors` hash on the model instance.

```rb
photo = Photo.new
photo.image = image_file
photo.valid? #=> false
photo.errors[:image] #=> [...]
```

By default the invalid file will remain assigned to the attachment attribute,
but you can have it automatically removed and deleted by loading the
`remove_invalid` plugin.

```rb
Shrine.plugin :remove_invalid # remove and delete files that failed validation
```

The validation block is evaluated in the context of a `Shrine::Attacher`
instance, so you have access to the original file and the record:

```rb
class ImageUploader < Shrine
  Attacher.validate do
    self   #=> #<Shrine::Attacher>

    get    #=> #<Shrine::UploadedFile>
    record #=> #<Photo>
    name   #=> :image
  end
end
```

You can use the attacher context to pass additional parameters you want to use
for validation:

```rb
photo.image_attacher.context[:foo] = "bar"
```
```rb
class ImageUploader < Shrine
  Attacher.validate do
    context[:foo] #=> "bar"
  end
end
```

## Validation helpers

The `validation_helpers` plugin provides helper methods for validating common
metadata values:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_min_size 1, message: "must not be empty"
    validate_max_size 5*1024*1024, message: "is too large (max is 5 MB)"
    validate_mime_type_inclusion %w[image/jpeg image/png image/tiff]
    validate_extension_inclusion %w[jpg jpeg png tiff tif]
  end
end
```

Note that for secure MIME type validation it's recommended to also load
`determine_mime_type` and `restore_cached_data` plugins.

It's also easy to do conditional validations with these helper methods:

```rb
class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    # validate dimensions only of the attached file is an image
    if validate_extension_inclusion %w[jpg jpeg png tiff tif]
      validate_max_width 5000
      validate_max_height 5000
    end
  end
end
```

See the `validation_helpers` plugin documentation for more details.

## Custom validations

You might sometimes want to validate custom metadata, or in general do custom
validation that the `validation_helpers` plugin does not provide. The
`Shrine::Attacher.validate` block is evaluated at instance level, so you're
free to write there any code you like and add validation errors onto the
`Shrine::Attacher#errors` array.

For example, if you're uploading images, you might want to validate that the
image is processable using the [ImageProcessing] gem:

```rb
require "image_processing/mini_magick"

class ImageUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    # validate dimensions only of the attached file is an image
    if validate_mime_type_inclusion %w[image/jpeg image/png image/tiff]
      get.download do |tempfile|
        errors << "is corrupted or invalid" unless ImageProcessing::MiniMagick.valid_image?(tempfile)
      end
    end
  end
end
```

## Inheritance

Validations are inherited from superclasses, but you need to call them manually
when defining more validations:

```rb
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

[ImageProcessing]: https://github.com/janko-m/image_processing
