# processing

Shrine uploaders can define the `#process` method, which will get called
whenever a file is uploaded. It is given the original file, and is expected to
return the processed files.

```rb
def process(io, context)
  # you can process the original file `io` and return processed file(s)
end
```

However, when handling files as attachments, the same file is uploaded to
temporary and permanent storage. Since we only want to apply the same
processing once, we need to branch based on the context.

```rb
def process(io, context)
  if context[:action] == :store # promote phase
    # ...
  end
end
```

The `processing` plugin simplifies this by allowing us to declaratively define
file processing for specified actions.

```rb
plugin :processing

process(:store) do |io, context|
  # ...
end
```

An example of resizing an image using the [image_processing] library:

```rb
require "image_processing/mini_magick"

process(:store) do |io, context|
  io.download do |original|
    ImageProcessing::MiniMagick
      .source(original)
      .resize_to_limit!(800, 800)
  end
end
```

The declarations are additive and inheritable, so for the same action you can
declare multiple blocks, and they will be performed in the same order, with
output from previous block being the input to next.

## Manually Run Processing

You can manually trigger the defined processing via the uploader by calling
`#upload` or `#process` and setting `:action` to the name of your processing
block:

```rb
uploader.upload(file, action: :store)  # process and upload
uploader.process(file, action: :store) # only process
```

If you want the result of processing to be multiple files, use the `versions`
plugin.

[image_processing]: https://github.com/janko/image_processing
