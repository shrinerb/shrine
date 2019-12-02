### Highlights

* Modular and memory-friendly design
* Storage options from disk to cloud and from single to multiple storages
* Persistence integrations for a variety of ORM's with validation
* Works with all the web frameworks - Roda, Rails, Hanami, Sinatra, etc
* Configurable architecture from simple file upload to direct upload, eager or on-the-fly processing, resumable uploads, background processing, etc

### Code Sample

#### Setup the storages ...

```rb
Shrine.storages = {
  cache: Shrine::Storage::S3.new(prefix: "cache", **s3_options), # temporary
  store: Shrine::Storage::S3.new(**s3_options),                  # permanent
}
```

#### Easily attach files ...

```rb
# using :sequel plugin

class Photo < Sequel::Model
  include Shrine::Attachment(:image)
end
```
```rb
photo = Photo.create(image: file)

photo.image          #=> #<Shrine::UploadedFile>
photo.image_url      #=> "https://my-bucket.s3.amazonaws.com/6bfafe89748ee135.jpg"

photo.image.id       #=> "6bfafe89748ee135.jpg"
photo.image.storage  #=> #<Shrine::Storage::S3>
photo.image.metadata #=> { "size" => 749238, "mime_type" => "image/jpeg", "filename" => "nature.jpg" }
```

#### Process them eagerly...

```rb
# using :derivatives plugin

Shrine::Attacher.derivatives :thumbnails do |original|
  magick = ImageProcessing::MiniMagick.source(original)

  { large:  magick.resize_to_limit!(800, 800),
    medium: magick.resize_to_limit!(500, 500),
    small:  magick.resize_to_limit!(300, 300) }
end
```
```rb
photo.image_derivatives #=>
# { large:  #<Shrine::UploadedFile id="4ed847866c71a5bf.jpg" ...>,
#   medium: #<Shrine::UploadedFile id="7bc41b1c24afe81d.jpg" ...>,
#   small:  #<Shrine::UploadedFile id="cccdd4052261633b.jpg" ...> }
```

#### Or on-the-fly...

```rb
# using :derivation_endpoint plugin

Shrine.derivation :thumbnail do |file, width, height|
  magick = ImageProcessing::MiniMagick.source(original)
  magick.resize_to_limit!(width.to_i, height.to_i)
end
```
```rb
photo.image.derivation_url(:thumbnail, 600, 400)
#=> ".../thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```

#### Serve the file URLs

```rb
photo.image_url           #=> "https://my-bucket.s3.amazonaws.com/6bfafe89748ee135.jpg"
photo.image[:small].url   #=> "https://my-bucket.s3.amazonaws.com/cccdd4052261633b.jpg"
```
