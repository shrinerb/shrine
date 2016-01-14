# Changing Location of Files

You have a production app with already uploaded attachments. However, you've
realized that the existing store folder structure for attachments isn't working
for you.

The first step is to change the location, either by using the `pretty_location`
plugin:

```rb
Shrine.plugin :pretty_location
```

Or by overriding `#generate_location`:

```rb
class MyUploader < Shrine
  def generate_location(io, context)
    "#{context[:record].class}/#{context[:record].id}/#{io.original_filename}"
  end
end
```

After you've deployed this change, all existing attachments on old locations
will continue to work properly. The next step is to run a script that will
move those to new locations. The easiest way to do that is to reupload them:

```rb
Shrine.plugin :migration_helpers # before the model is loaded
Shrine.plugin :multi_delete # for deleting multiple files at once
```
```rb
old_avatars = []

User.paged_each do |user|
  user.update_avatar do |avatar|
    old_avatars << avatar
    user.avatar_store.upload(avatar)
  end
end

if old_avatars.any?
  # you'll have to change this code slightly if you're using versions
  uploader = old_avatars.first.uploader
  uploader.delete(old_avatars)
end
```

And now all your existing attachments should be happily living on new
locations.
