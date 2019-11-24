You can attach files...

```rb
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

...and process them eagerly...

```rb
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

...or on-the-fly...

```rb
Shrine.derivation :thumbnail do |file, width, height|
  magick = ImageProcessing::MiniMagick.source(original)
  magick.resize_to_limit!(width.to_i, height.to_i)
end
```
```rb
photo.image.derivation_url(:thumbnail, 600, 400)
#=> ".../thumbnail/600/400/eyJpZCI6ImZvbyIsInN0b3JhZ2UiOiJzdG9yZSJ9?signature=..."
```
