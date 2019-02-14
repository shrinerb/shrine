# Validation Helpers

The [`validation_helpers`][validation_helpers] plugin provides helper methods
for validating attached files based on extracted metadata.

```rb
plugin :validation_helpers

Attacher.validate do
  validate_mime_type_inclusion %w[image/jpeg image/png image/gif]
  validate_max_size 5*1024*1024 if record.guest?
end
```

## Validators

### File size

The `#validate_max_size`/`#validate_min_size` methods accept a number of bytes,
and validate that the `size` metadata value is not larger or smaller than the
specified size.

```rb
validate_max_size 5*1024*1024 # file must be smaller than 5 MB
validate_min_size 1024        # file must be larger than 1 KB
```

### MIME type

The `#validate_mime_type_inclusion`/`#validate_mime_type_exclusion` methods
accept a list of MIME types, and validate that the `mime_type` metadata value
is (not) a member of that list.

```rb
validate_mime_type_inclusion %w[image/jpeg image/png image/gif] # file must be a JPEG, PNG or a GIF image
validate_mime_type_exclusion %w[application/x-php]              # file must not be a PHP script
```

### File extension

The `#validate_extension_inclusion`/`#validation_extension_exclusion` methods
accept a list of file extensions, and validate that the `filename` metadata
value extension is (not) a member of that list.

```rb
validate_extension_inclusion %w[jpg jpeg png gif] # file must have .jpg, .jpeg, .png, or .gif extension
validate_extension_exclusion %w[php]              # file must not have a .php extension
```

Since file extension doesn't have to match the type of the file, it's good
practice to validate both the file extension and the MIME type.

### Image Dimensions

The `#validate_max_width`/`#validate_min_width` methods accept a width in
pixels, and validates that the `width` metadata value is not larger or smaller
than the specified number:

```rb
validate_max_width 5000 # image width must be smaller than 5000px
validate_min_width 100  # image width must be larger than 100px
```

The `#validate_max_height`/`#validate_min_height` methods accept a height in
pixels, and validates that the `height` metadata value is not larger or smaller
than the specified number:

```rb
validate_max_height 5000 # image height must be smaller than 5000px
validate_min_height 100  # image height must be larger than 100px
```

It's good practice to validate dimensions in addition to filesize, as a guard
against decompression attacks. Note that these validations only make sense if
the `store_dimensions` plugin is loaded, so that image dimensions are extracted.

```rb
plugin :store_dimensions
```

## Dynamic evaluation

The validation block is evaluated dynamically in the context of a
`Shrine::Attacher` instance, so you can access the attachment name, record and
context:

```rb
Attacher.validate do
  self    #=> #<Shrine::Attacher>
  name    #=> :image
  record  #=> #<Photo>
  context #=> { ... }

  # ...
end
```

The validation methods return whether the validation succeeded, allowing you to
easily do conditional validation:

```rb
Attacher.validate do
  if validate_mime_type_inclusion %w[image/jpeg image/png image/gif]
    validate_max_width 2000
    validate_max_height 2000
  end
end
```

## Error messages

If you would like to change default validation error messages, you can pass in
the `:default_messages` option to the plugin:

```rb
plugin :validation_helpers, default_messages: {
  max_size: ->(max) { I18n.t("errors.file.max_size", max: max) },
  mime_type_inclusion: ->(whitelist) { I18n.t("errors.file.mime_type_inclusion", whitelist: whitelist) },
}
```

If you would like to change the error message inline, you can pass the
`:message` option to any validation method:

```rb
Attacher.validate do
  validate_mime_type_inclusion %w[image/jpeg image/png image/gif], message: "must be JPEG, PNG or GIF"
end
```

[validation_helpers]: /lib/shrine/plugins/validation_helpers.rb
