# Multiple Files

There are often times when you want to allow users to attach multiple files to
a single resource. Some file attachment libraries provide a special interface
for multiple attachments, but Shrine doesn't come with one, because it's much
more robust and flexible to implement this using your ORM directly.

The idea is to create a new table, and attach each uploaded file to a separate
record on that table, while having a "many-to-one" relationship with the main
table. That way a database record from the main table can implicitly have
multiple attachments through the associated records.

```
album
  photo1
    - attachment1
  photo2
    - attachment2
  photo3
    - attachment3
```

This design gives you great flexibility, allowing you to support:

* adding new attachments
* updating existing attachments
* removing existing attachments
* sorting attachments
* having additional fields on attachments (captions, votes, number of downloads etc.)
* ...

If you're using Sequel or ActiveRecord, the easiest way to implement this is
via nested attributes, which you would in general use for any dynamic
"one-to-many" association. The examples will be using Sequel, but with
ActiveRecord it's very similar, here are the docs:

* [`Sequel::Model.nested_attributes`]
* [`ActiveRecord::Base.accepts_nested_attributes_for`]

For simplicity, for the rest of this guide we will assume that we have "albums"
that can have multiple "photos".

## 1. Attachments table

Let's create a table for our attachments, and add a foreign key for the main table:

```rb
Sequel.migration do
  change do
    create_table :photos do
      primary_key :id
      foreign_key :album_id, :albums
      column      :image_data, :text
    end
  end
end
```

In our new model we can create a Shrine attachment attribute:

```rb
class Photo < Sequel::Model
  include ImageUploader[:image]
end
```

## 2. Nested attributes

In our main model we can now declare the association to the new table, and
allow it to directly accept attributes for the associated records:

```rb
class Album < Sequel::Model
  one_to_many :photos

  plugin :nested_attributes # load the plugin
  nested_attributes :photos
end
```

## 3. View

In order to allow the user to select multiple files in the form, we just need
to add the `multiple` attribute to the file field.

```html
<input type="file" multiple name="file">
```

You can then use a generic JavaScript file upload library like
[jQuery-File-Upload], [Dropzone] or [FineUploader] to asynchronously upload
each the selected files to your app or an external service. See the
`direct_upload` plugin, and [Direct Uploads to S3] guide for more details.

After each upload finishes, you can generate a nested hash for the new
associated record, and write the uploaded file JSON to the attachment field:

```rb
album[photos_attributes][0][image] = '{"id":"38k25.jpg","storage":"cache","metadata":{...}}'
album[photos_attributes][1][image] = '{"id":"sg0fg.jpg","storage":"cache","metadata":{...}}'
album[photos_attributes][2][image] = '{"id":"041jd.jpg","storage":"cache","metadata":{...}}'
```

Once you submit this to the app, the ORM's nested attributes behaviour will
create the associated records, and assign the Shrine attachments.

Now you can manage adding new, or updating and deleting existing attachments,
just by using your ORM's nested attributes behaviour, the same way that you
would do with any other dynamic one-to-many association. The callbacks that
are added by including the Shrine module to the associated model will
automatically take care of the attachment management.

[`Sequel::Model.nested_attributes`]: http://sequel.jeremyevans.net/rdoc-plugins/classes/Sequel/Plugins/NestedAttributes.html
[`ActiveRecord::Base.accepts_nested_attributes_for`]: http://api.rubyonrails.org/classes/ActiveRecord/NestedAttributes/ClassMethods.html
[jQuery-File-Upload]: https://github.com/blueimp/jQuery-File-Upload
[Dropzone]: https://github.com/enyo/dropzone
[FineUploader]: https://github.com/FineUploader/fine-uploader
[Direct Uploads to S3]: http://shrinerb.com/rdoc/files/doc/direct_s3_md.html
