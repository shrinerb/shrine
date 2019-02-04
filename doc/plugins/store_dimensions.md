# Store Dimensions

The `store_dimensions` plugin extracts dimensions of uploaded images and stores
them into the metadata hash (by default it uses the [fastimage] gem).

```rb
plugin :store_dimensions
```

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

You can use methods for extracting the dimensions directly:

```rb
# or YourUploader.extract_dimensions(io)
Shrine.extract_dimensions(io) # calls the defined analyzer
#=> [300, 400]

# or YourUploader.dimensions_analyzers
Shrine.dimensions_analyzers[:fastimage].call(io) # calls a built-in analyzer
#=> [300, 400]
```

[fastimage]: https://github.com/sdsykes/fastimage
[mini_magick]: https://github.com/minimagick/minimagick
[ruby-vips]: https://github.com/libvips/ruby-vips
