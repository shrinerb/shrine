---
title: Versions
---

The [`versions`][versions] plugin enables your uploader to deal with versions,
by allowing you to return a Hash of files when processing.

```rb
plugin :versions
```

Here is an example of processing image thumbnails using the [image_processing]
gem:

```rb
require "image_processing/mini_magick"

plugin :processing

process(:store) do |io, context|
  versions = { original: io } # retain original

  io.download do |original|
    pipeline = ImageProcessing::MiniMagick.source(original)

    versions[:large]  = pipeline.resize_to_limit!(800, 800)
    versions[:medium] = pipeline.resize_to_limit!(500, 500)
    versions[:small]  = pipeline.resize_to_limit!(300, 300)
  end

  versions # return the hash of processed files
end
```

You probably want to load the `delete_raw` plugin to automatically delete
processed files after they have been uploaded.

Now when you access the stored attachment through the model, a hash of uploaded
files will be returned:

```rb
user.avatar_data #=>
# '{
#   "original": {"id":"0gsdf.jpg", "storage":"store", "metadata":{...}},
#   "large": {"id":"lg043.jpg", "storage":"store", "metadata":{...}},
#   "medium": {"id":"kd9fk.jpg", "storage":"store", "metadata":{...}},
#   "small": {"id":"932fl.jpg", "storage":"store", "metadata":{...}}
# }'

user.avatar #=>
# {
#   :original => #<Shrine::UploadedFile @data={"id"=>"0gsdf.jpg", ...}>,
#   :large    => #<Shrine::UploadedFile @data={"id"=>"lg043.jpg", ...}>,
#   :medium   => #<Shrine::UploadedFile @data={"id"=>"kd9fk.jpg", ...}>,
#   :small    => #<Shrine::UploadedFile @data={"id"=>"932fl.jpg", ...}>,
# }

user.avatar[:medium]     #=> #<Shrine::UploadedFile>
user.avatar[:medium].url #=> "/uploads/store/lg043.jpg"
```

The plugin also extends the `Attacher#url` to accept versions:

```rb
user.avatar_url(:large)
user.avatar_url(:small, public: true) # with URL options
```

`Shrine.uploaded_file` will also instantiate a hash of `Shrine::UploadedFile`
objects if given data with versions. If you want to apply a change to all files
in an attachment, regardless of whether it consists of a single file or a hash
of versions, you can pass a block to `Shrine.uploaded_file` and it will yield
each file:

```rb
Shrine.uploaded_file(attachment_data) do |uploaded_file|
  # ...
end
```

## Fallbacks

If versions are processed in a background job, there will be a period where the
user will browse the site before versions have finished processing. In this
period `Attacher#url` will by default fall back to the original file.

```rb
user.avatar #=> #<Shrine::UploadedFile>
user.avatar_url(:large) # falls back to `user.avatar_url`
```

This behaviour is convenient if you want to gracefully degrade to the cached
file until the background job has finished processing. However, if you would
rather provide your own default URLs for versions, you can disable this
fallback:

```rb
plugin :versions, fallback_to_original: false
```

If you already have some versions processed in the foreground after a
background job is kicked off (with the `recache` plugin), you can have URLs for
versions that are yet to be processed fall back to existing versions:

```rb
plugin :versions, fallbacks: {
  :thumb_2x => :thumb,
  :large_2x => :large,
}

# ... (background job is kicked off)

user.avatar_url(:thumb_2x) # returns :thumb URL until :thumb_2x becomes available
user.avatar_url(:large_2x) # returns :large URL until :large_2x becomes available
```

## Arrays

In addition to Hashes, the plugin also supports Arrays of files. For example,
you might want to split a PDf into pages:

```rb
process(:store) do |io, context|
  versions = { pages: [] }

  io.download do |pdf|
    page_count = MiniMagick::Image.new(pdf.path).pages.count
    pipeline   = ImageProcessing::MiniMagick.source(pdf).convert("jpg")

    page_count.times do |page_number|
      versions[:pages] << pipeline.loader(page: page_number).call
    end
  end

  versions
end
```

You can also combine Hashes and Arrays, there is no limit to the level of
nesting.

## Original file

It's recommended to always keep the original file after processing versions,
which you can do by adding the yielded `Shrine::UploadedFile` object as one of
the versions, by convention named `:original`:

```rb
process(:store) do |io, context|
  # processing thumbnail
  { original: io, thumbnail: thumbnail }
end
```

If both temporary and permanent storage are Amazon S3, the cached original will
simply be copied over to permanent storage (without any downloading and
reuploading), so in these cases the performance impact of storing the original
file in addition to processed versions is neglibible.

## Context

The version name will be available via `:version` when generating location or a
default URL.

```rb
def generate_location(io, context)
  "uploads/#{context[:version]}-#{super}"
end

Attacher.default_url do |options|
  "/images/defaults/#{options[:version]}.jpg"
end
```

[versions]: https://github.com/shrinerb/shrine/blob/master/lib/shrine/plugins/versions.rb
[image_processing]: https://github.com/janko/image_processing
