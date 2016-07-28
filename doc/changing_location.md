# Migrating to Different Location

You have a production app with already uploaded attachments. However, you've
realized that the existing store folder structure for attachments isn't working
for you.

The first step is to change the location, by overriding `#generate_location` or
with the pretty_location plugin, and deploy that change. This will make any new
files upload to the desired location, attachments on old locations will still
continue to work normally.

The next step is to run a script that will move old files to new locations. The
easiest way to do that is to reupload them and delete them. Shrine has a method
exactly for that, `Attacher#promote`, which also handles the situation when
someone attaches a new file during "moving" (since we're running this script on
live production).

```rb
Shrine.plugin :delete_promoted

User.paged_each do |user|
  attacher = user.avatar_attacher
  attacher.promote(action: :migrate) if attacher.stored?
  # use `attacher._promote(action: :migrate)` if you want promoting to be backgrounded
end
```

The `:action` is not mandatory, it's just for better introspection when
monitoring background jobs and logs.

Now all your existing attachments should be happily living on new locations.
