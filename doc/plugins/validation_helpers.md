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
and validate that the `size` metadata value is not greater/less than the
specified size.

```rb
validate_max_size 5*1024*1024 # file size must not be greater than 5 MB
validate_min_size 1024        # file size must not be less than 1 KB
```

You can also use the `#validate_size` method, which combines these two:

```rb
validate_size 1024..5*1024*1024 # file size must not be greater than 5 MB nor less than 1 KB
```

### MIME type

The `#validate_mime_type_inclusion`/`#validate_mime_type_exclusion` methods
accept a list of MIME types, and validate that the `mime_type` metadata value
is/is not a member of that list.

```rb
validate_mime_type_inclusion %w[image/jpeg image/png image/gif] # file must be a JPEG, PNG or a GIF image
validate_mime_type_exclusion %w[application/x-php]              # file must not be a PHP script
```

Instead of `#validate_mime_type_inclusion` you can also use just
`#validate_mime_type`.

### File extension

The `#validate_extension_inclusion`/`#validation_extension_exclusion` methods
accept a list of file extensions, and validate that the `filename` metadata
value extension is/is not a member of that list.

```rb
validate_extension_inclusion %w[jpg jpeg png gif] # file must have .jpg, .jpeg, .png, or .gif extension
validate_extension_exclusion %w[php]              # file must not have a .php extension
```

Instead of `#validate_extension_inclusion` you can also use just
`#validate_extension`.

Since file extension doesn't have to match the type of the file, it's good
practice to validate both the file extension and the MIME type.

### Image Dimensions

These validations validate `width` and `height` metadata values, which are
extracted by the `store_dimensions` plugin.

```rb
plugin :store_dimensions
```

It's good practice to validate dimensions in addition to filesize, as a guard
against decompression attacks.

#### Width

The `#validate_max_width`/`#validate_min_width` methods accept a width in
pixels, and validates that the `width` metadata value is not greater/less
than the specified number:

```rb
validate_max_width 5000 # image width must not be greater than 5000px
validate_min_width 100  # image width must not be less than 100px
```

You can also use the `#validate_width` method, which combines these two:

```rb
validate_width 100..5000 # image width must not be greater than 5000px nor less than 100px
```

#### Height

The `#validate_max_height`/`#validate_min_height` methods accept a height in
pixels, and validates that the `height` metadata value is not greater/less
than the specified number:

```rb
validate_max_height 5000 # image height must not be greater than 5000px
validate_min_height 100  # image height must not be less than 100px
```

You can also use the `#validate_height` method, which combines these two:

```rb
validate_height 100..5000 # image height must not be greater than 5000px nor less than 100px
```

#### Width & Height

The `#validate_max_dimensions`/`#validate_min_dimensions` methods accept an
array of width and height in pixels, and validates that the `width` and
`height` metadata values are not greater/less than the specified numbers:

```rb
validate_max_dimensions [5000, 5000] # image dimensions must not be greater than 5000x5000
validate_min_dimensions [100, 100]   # image dimensions must not be less than 100x100
```

You can also use the `#validate_dimensions` methods, which combines these two:

```rb
validate_dimensions [100..5000, 100..5000] # image dimensions must not be greater than 5000x5000 nor less than 100x100
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
