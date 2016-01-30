# Changing Location of Files

You have a production app with already uploaded attachments. However, you've
realized that the existing store folder structure for attachments isn't working
for you.

The first step is to change the location (by overriding `#generate_location` or
with the pretty_location plugin), and deploy that change. Attachments on old
locations will still continue to work properly.

The next step is to run a script that will move those to new locations. The
easiest way to do that is to reupload them, and afterwards delete them:

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
