# Multiple Files

There are times when you want to allow users to attach multiple files to a single resource like an album having many photos or a playlist having many songs. Some file attachment libraries provide a special interface for multiple attachments, but Shrine doesn't have one because it's much more robust and flexible to implement this using your ORM directly.

The basic idea to implement this in Shrine is to create a separate files table from the main resource table, and attach each uploaded file to a separate record on the files table. Next you'll use a "one-to-many" relationship between the main resource table and the files table to track which files belongs to which main resource just like you do with other "one-to-many" associated database models. Each database record from the main table can implicitly have multiple attachments through the associated records.

```
album1
  photo1
    - attachment1
  photo2
    - attachment2
  photo3
    - attachment3
```

This design gives you the greatest flexibility, allowing you to support:
* adding new attachments
* updating existing attachments
* removing existing attachments
* sorting attachments
* having additional fields on attachments (e.g. captions, votes, number of downloads etc.)
* expanding this to be "many-to-many" relation (e.g. create different playlists from a list of songs, etc)
* ...


## How to Implement

For the rest of this guide, we will use the example where we have "albums" that can have multiple "photos" in it. The main table is the albums table and the files (or attachments) table will be the photos table.

### 1. Create the main resource and attachment table

Let's create a table for the main resource and attachments, and add a foreign key in the attachment table for the main table:

```rb
# Sequel
Sequel.migration do
  change do
    create_table :albums do
      primary_key :id
      column      :title, :text
    end
  end

  change do
    create_table :photos do
      primary_key :id
      foreign_key :album_id, :albums
      column      :image_data, :text
    end
  end
end

# Active Record
class CreateAlbumsAndPhotos < ActiveRecord::Migration[5.1]
  def change
    create_table :albums do |t|
      t.string      :title
      t.timestamps
    end

    create_table :photos do |t|
      t.text        :image_data
      t.references  :album, foreign_key: true
      t.timestamps
    end
  end
end
```

In the Photo model, create a Shrine attachment attribute named `image` (`:image` matches the `_data` column prefix above):

```rb
# Sequel
class Photo < Sequel::Model
  include ImageUploader::Attachment.new(:image)
end

# Active Record
class Photo < ActiveRecord::Base
  include ImageUploader::Attachment.new(:image)
end
```

### 2. Use nested attributes

Using nested attributes is the easiest way to implement any dynamic "one-to-many" association. Let's declare the association to the Photo table in the Album model, and allow it to directly accept attributes for the associated photo records:

```ruby
# Sequel
class Album < Sequel::Model
  one_to_many :photos
  plugin :nested_attributes # load the plugin
  nested_attributes :photos
end

# Active Record
class Album < ActiveRecord::Base
  has_many :photos
  accepts_nested_attributes_for :photos
end
```

Documentation on nested attributes:
* [`Sequel::Model.nested_attributes`]
* [`ActiveRecord::Base.accepts_nested_attributes_for`]

### 3. Create the View

Create a form like you normally do to create the album and photos with file field. In the form, add the `multiple` attribute to the file field so the user can select multiple files.

```rb
f.input :file, attr: { multiple: true }
# This translates into HTML: <input type="file" multiple="true" />
```

On the client side, you will need to asynchronously upload each of the selected files to a direct upload endpoint. There are 2 methods of implementing direct uploads: upload to your server app using the `upload_endpoint` plugin and upload to directly to storage like S3 using `presign_endpoint` plugin. For details on how to implement this, refer to the documentation on [`upload_endpoint`] plugin, [`presign_endpoint`] plugin, and [Direct Uploads to S3] guide.

After each of the files in the form has completed uploading on the client side (and the form has not been submitted yet), generate a nested hash for the new associated photo record, and write the uploaded file JSON to the `image` attachment field in the corresponding `photos` record. Remember we are using nested attributes so follow the nested attributes conventions in order to create both the album and photos upon submitting the form.

```rb
# Photos data the form will submit (album data is not shown)
album[photos_attributes][0][image] = '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
album[photos_attributes][1][image] = '{"id":"sg0fg.jpg","storage":"cache","metadata":{...}}'
album[photos_attributes][2][image] = '{"id":"041jd.jpg","storage":"cache","metadata":{...}}'
```

Once the form submits this data to the app, the ORM's nested attributes behaviour will create the associated `Photo` records, and assign the corresponding Shrine attachments as `image` to it. You may need to whitelist the params being passed into your controller. You can also add file validations in the `Photo` model using Shrine's `validation_helpers` plugin and/or Active Record validations for the associations like you normally would for any one-to-many Active Record models.

Now you can manage adding new attachments, or updating and deleting existing attachments, by using your ORM's nested attributes behaviour the same way you would do with any other dynamic one-to-many association. The callbacks that are added by including the Shrine module to the associated model will automatically take care of the attachment management.

[`Sequel::Model.nested_attributes`]: http://sequel.jeremyevans.net/rdoc-plugins/classes/Sequel/Plugins/NestedAttributes.html
[`ActiveRecord::Base.accepts_nested_attributes_for`]: http://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html
[`upload_endpoint`]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/UploadEndpoint.html
[`presign_endpoint`]: https://shrinerb.com/rdoc/classes/Shrine/Plugins/PresignEndpoint.html
[Direct Uploads to S3]: https://shrinerb.com/rdoc/files/doc/direct_s3_md.html
