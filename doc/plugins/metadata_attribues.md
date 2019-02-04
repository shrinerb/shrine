# metadata_attributes

The `metadata_attributes` plugin allows you to sync attachment metadata to
additional record attributes. You can provide a hash of mappings to the plugin
call itself or the `Attacher.metadata_attributes` method:

```rb
plugin :metadata_attributes, :size => :size, :mime_type => :type
# or
plugin :metadata_attributes
Attacher.metadata_attributes :size => :size, :mime_type => :type
```

The above configuration will sync `size` metadata field to `<attachment>_size`
record attribute, and `mime_type` metadata field to `<attachment>_type` record
attribute.

```rb
user.avatar = image
user.avatar.metadata["size"]      #=> 95724
user.avatar_size                  #=> 95724
user.avatar.metadata["mime_type"] #=> "image/jpeg"
user.avatar_type                  #=> "image/jpeg"

user.avatar = nil
user.avatar_size #=> nil
user.avatar_type #=> nil
```

If you want to specify the full record attribute name, pass the record
attribute name as a string instead of a symbol.

```rb
Attacher.metadata_attributes :filename => "original_filename"

# ...

photo.image = image
photo.original_filename #=> "nature.jpg"
```

If any corresponding metadata attribute doesn't exist on the record, that
metadata sync will be silently skipped.
