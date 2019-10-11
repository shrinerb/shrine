---
id: multiple-files
title: Multiple Files
---

There are times when you want to allow users to attach multiple files to a
single resource, like an album having many photos or a playlist having many
songs. Some file attachment libraries provide a special interface for multiple
attachments, but Shrine doesn't have one, because it's more flexible to use
the "nested attributes" feature of your ORM directly to implement this.

The basic idea is to create a separate table that will have a many-to-one
relationship with the main table, and files will be attached on the records in
the new table. That way each record from the main table can implicitly have
multiple attachments through the associated records.

```
album1
  photo1
    - attachment1
  photo2
    - attachment2
  photo3
    - attachment3

album2
  photo4
    - attachment4
  photo5
    - attachment5

...
```

To illustrate, this code will create an album with three photos using nested
attributes:

```rb
Album.create(
  title: "My Album",
  photos_attributes: [
    { image: File.open("image1.jpg", binmode: true) },
    { image: File.open("image2.jpg", binmode: true) },
    { image: File.open("image3.jpg", binmode: true) },
  ]
)
```

This design gives you the greatest flexibility, allowing you to support:

* adding new attachments
* updating existing attachments
* removing existing attachments
* sorting attachments (via a separate position column)
* having additional fields on attachments (e.g. captions, votes, number of downloads etc.)
* expanding this to be "many-to-many" relation (e.g. create different playlists from a list of songs, etc)
* ...

## How to Implement

For the rest of this guide, we will use the example where we have "albums" that
can have multiple "photos" in it. The main table is the albums table and the
files (or attachments) table will be the photos table.

### 1. Create the main resource and attachment table

Let's create a table for the main resource and attachments, and add a foreign
key in the attachment table for the main table:

```rb
# with Sequel:
Sequel.migration do
  change do
    create_table :albums do
      primary_key :id
      column      :title, :text
    end

    create_table :photos do
      primary_key :id
      foreign_key :album_id, :albums
      column      :image_data, :text
    end
  end
end

# with Active Record:
class CreateAlbumsAndPhotos < ActiveRecord::Migration
  def change
    create_table :albums do |t|
      t.string     :title
      t.timestamps
    end

    create_table :photos do |t|
      t.references :album, foreign_key: true
      t.text       :image_data
      t.timestamps
    end
  end
end
```

In the Photo model, create a Shrine attachment attribute named `image`
(`:image` matches the `_data` column prefix above):

```rb
# with Sequel:
class Photo < Sequel::Model
  include ImageUploader::Attachment(:image)
end

# with Active Record:
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment(:image)
end
```

### 2. Declare nested attributes

Using nested attributes is the easiest way to implement any dynamic
"one-to-many" association. In the Album model we'll declare a one-to-many
relationship to the photos table, and allow it to directly accept attributes
for the associated photo records by enabling nested attributes:

```rb
# with Sequel:
class Album < Sequel::Model
  one_to_many :photos
  plugin :association_dependencies, photos: :destroy # destroy photos when album is destroyed

  plugin :nested_attributes
  nested_attributes :photos, destroy: true
end

# with Active Record:
class Album < ActiveRecord::Base
  has_many :photos, dependent: :destroy
  accepts_nested_attributes_for :photos, allow_destroy: true
end
```

Documentation on nested attributes:

* [`Sequel::Model.nested_attributes`]
* [`ActiveRecord::Base.accepts_nested_attributes_for`]
* [`Mongoid::Document.accepts_nested_attributes_for`]

### 3. Create the View

Create a form like you normally do to create the album. To this form we'll add
a file field for selecting photos, which will have `multiple` attribute to
allow the user to select multiple files. We'll also display nested fields for
already created photos, so that the same form can be used for updating the
album/photos as well (they will be submitted under the
`album[photos_attributes]` parameter).

```rb
# with Forme:
form @album, action: "/photos", enctype: "multipart/form-data" do |f|
  f.input :title
  f.subform :photos do # adds new `album[photos_attributes]` parameter
    f.input :image,   type: :hidden, value: f.obj.cached_image_data
    f.input :image,   type: :file
    f.input :_delete, type: :checkbox unless f.obj.new?
  end
  f.input "files[]", type: :file, attr: { multiple: true }, obj: nil
  f.button "Create"
end

# with Rails form builder:
form_for @album, html: { enctype: "multipart/form-data" } do |f|
  f.text_field :title
  f.fields_for :photos do |p| # adds new `album[photos_attributes]` parameter
    p.hidden_field :image, value: p.object.cached_image_data
    p.file_field   :image
    p.check_box    :_destroy unless p.object.new_record?
  end
  file_field_tag "files[]", multiple: true
  f.submit "Create"
end
```

In your controller you should still be able to assign all the attributes to the
album, just remember to whitelist the new parameter for the nested attributes,
in this case `album[photos_attributes]`.

### 4a. Form upload

If you would like to avoid writing JavaScript, you can have selected files
uploaded via the form, and then in your controller you can assign them in the
format of nested attributes. You'll want to merge these newly uploaded photos
with the existing photos params that will come from the nested form fields.
This could look something like this:

```rb
# In your controller:

# transform the list of uploaded files into a photos attributes hash
new_photos_attributes = params[:files].inject({}) do |hash, file|
  hash.merge!(SecureRandom.hex => { image: file })
end

# merge new photos attributes with existing (`album_params` is whitelisted `params[:album]`)
photos_attributes = album_params[:photos_attributes].to_h.merge(new_photos_attributes)
album_attributes  = album_params.merge(photos_attributes: photos_attributes)

# create the album with photos
Album.create(album_params)
```

In this case you need to make sure your form tag has
`enctype="multipart/form-data"` attributes specified, otherwise form upload
won't succeed.

### 4b. Direct upload

Alternatively, you can have selected files immediately uploaded to a direct
upload endpoint, as soon as they're selected. It's recommended to use [Uppy]
for handling client side file uploads. There are two methods of implementing
direct uploads: to your app using the [`upload_endpoint`] plugin, or directly
to a storage like S3 using the [`presign_endpoint`] plugin. See the
walkthroughs for setting up simple [direct app uploads] and [direct S3
uploads], as well as the [Roda][roda demo] or [Rails][rails demo] demo app
which implement multiple file uploads.

Once files are uploaded asynchronously, you can dynamically insert photo
attachment fields for the `image` attachment attribute into the form, where the
hidden field is filled with uploaded file data in JSON format, just like when
doing single direct uploads. The attachment field names should be namespaced
according to the convention that the nested attributes feature expects. In this
case it should be `album[photos_attributes][<uid>]`, where `<uid>` is any
unique string.

```rb
# naming format in which photos fields should be generated and submitted
album[photos_attributes][11111][image] = '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
album[photos_attributes][29323][image] = '{"id":"sg0fg.jpg","storage":"cache","metadata":{...}}'
album[photos_attributes][34820][image] = '{"id":"041jd.jpg","storage":"cache","metadata":{...}}'
```

In your controller you don't need to make any changes to handle the nested
photos attributes (other than allowing them), your ORM will take care of
creating, updating, or removing the associated photos.

```rb
Album.create(album_params) # or `params[:album]`
```

### 5. Adding Validations

You can add file validations to the `Photo` model using the
`validation_helpers` plugin. You just need to make sure that your ORM is
configured to automatically validate associated records.

```rb
class ImageUploader < Shrine
  plugin :validation_helpers
  plugin :determine_mime_type

  Attacher.validate do
    validate_max_size 10*1024*1024
    validate_mime_type %w[image/jpeg image/png image/webp]
  end
end
```
```rb
# with Sequel:
class Album < Sequel::Model
  # ... (nested_attributes already enables validating associated photos) ...
end

# with ActiveRecord:
class Album < ActiveRecord::Base
  # ...
  validates_associated :photos
end
```

Note that by default only metadata set on the client side will be available for
validations. Shrine will not automatically run metadata extraction for directly
uploaded files, as this would require (at least partially) downloading each
file from storage, which could be an unwanted performance penalty. If you want
metadata to be extracted on the server side, you can load the
`restore_cached_data` plugin which will make metadata extraction run on
assignment, or you can extract the metadata manually (e.g. in a background job)
using the `refresh_metadata` plugin.

### Conclusion

Now we have a simple interface for accepting multiple attachments, which
internally uses the nested attributes feature of your ORM to create multiple
associated records, each with a single attachment. After creation you can also
add new attachments, or update and delete existing ones, which the nested
attributes feature gives you for free.

[`Sequel::Model.nested_attributes`]: http://sequel.jeremyevans.net/rdoc-plugins/classes/Sequel/Plugins/NestedAttributes.html
[`ActiveRecord::Base.accepts_nested_attributes_for`]: http://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html
[`Mongoid::Document.accepts_nested_attributes_for`]: https://docs.mongodb.com/mongoid/master/tutorials/mongoid-nested-attributes/
[`upload_endpoint`]: https://shrinerb.com/docs/plugins/upload_endpoint
[`presign_endpoint`]: https://shrinerb.com/docs/plugins/presign_endpoint
[Uppy]: https://uppy.io
[direct app uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-App-Uploads
[direct S3 uploads]: https://github.com/shrinerb/shrine/wiki/Adding-Direct-S3-Uploads
[roda demo]: https://github.com/shrinerb/shrine/tree/master/demo
[rails demo]: https://github.com/erikdahlstrand/shrine-rails-example
