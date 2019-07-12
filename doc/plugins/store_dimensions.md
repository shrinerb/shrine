# Store Dimensions

The [`store_dimensions`][store_dimensions] plugin extracts dimensions of
uploaded images and stores them into the metadata hash (by default it uses the
[fastimage] gem).

```rb
plugin :store_dimensions
```

## Metadata

The dimensions are stored as "width" and "height" metadata values on the
Shrine::UploadedFile object. For convenience the plugin also adds `#width`,
`#height` and `#dimensions` reader methods.

```rb
image = uploader.upload(file)

image.metadata["width"]  #=> 300
image.metadata["height"] #=> 500
# or
image.width  #=> 300
image.height #=> 500
# or
image.dimensions #=> [300, 500]
```

## Analyzers

By default the [fastimage] gem is used to extract dimensions. You can choose a
different built-in analyzer via the `:analyzer` option:

```rb
plugin :store_dimensions, analyzer: :mini_magick
```

The following analyzers are supported:

| Name           | Description                                                                                                                                   |
| :-----------   | :-----------                                                                                                                                  |
| `:fastimage`   | (Default). Uses the [fastimage] gem to extract dimensions from any IO object.                                                                 |
| `:mini_magick` | Uses the [mini_magick] gem to extract dimensions from File objects. If non-file IO object is given it will be temporarily downloaded to disk. |
| `:ruby_vips`   | Uses the [ruby-vips] gem to extract dimensions from File objects. If non-file IO object is given it will be temporarily downloaded to disk.   |

You can also create your own custom dimensions analyzer, where you can reuse
any of the built-in analyzers. The analyzer is a lambda that accepts an IO
object and returns width and height as a two-element array, or `nil` if
dimensions could not be extracted.

```rb
plugin :store_dimensions, analyzer: -> (io, analyzers) do
  dimensions   = analyzers[:fastimage].call(io)   # try extracting dimensions with FastImage
  dimensions ||= analyzers[:mini_magick].call(io) # otherwise fall back to MiniMagick
  dimensions
end
```

## API

You can use methods for extracting the dimensions directly:

```rb
# or YourUploader.extract_dimensions(io)
Shrine.extract_dimensions(io) #=> [300, 400] (calls the defined analyzer)
# or just
Shrine.dimensions(io) #=> [300, 400] (calls the defined analyzer)

# or YourUploader.dimensions_analyzers
Shrine.dimensions_analyzers[:fastimage].call(io) #=> [300, 400] (calls a built-in analyzer)
```

## Errors

By default, any exceptions that the analyzer raises while extracting dimensions
will be caught and a warning will be printed out. This allows you to have the
plugin loaded even for files that are not images.

However, you can choose different strategies for handling these exceptions:

```rb
plugin :store_dimensions, on_error: :warn        # prints a warning (default)
plugin :store_dimensions, on_error: :fail        # raises the exception
plugin :store_dimensions, on_error: :ignore      # ignores exceptions
plugin :store_dimensions, on_error: -> (error) { # custom handler
  # report the exception to your exception handler
}
```

[store_dimensions]: /lib/shrine/plugins/store_dimensions.rb
[fastimage]: https://github.com/sdsykes/fastimage
[mini_magick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/libvips/ruby-vips
