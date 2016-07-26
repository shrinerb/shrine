# Reprocessing Versions

While your app is serving uploads in production, you may realize that you want
to change how your attachment's versions are generated. This means that, in
addition to changing you processing code, you also need to reprocess the
existing attachments. This guide is aimed to help doing this migration with
zero downtime and no unused files left in the main storage.

## Adding versions

Most common scenario is when initially you're not doing any processing, but
later decide that you want to generate versions. First you need to update your
code to generate versions, and you also need to change your views to use those
versions:

```rb
class ImageUploader < Shrine
  # ...

  process(:store) do |io, context|
    thumbnail = process_thumbnail(io.download)
    {original: io, thumbnail: thumbnail}
  end
end
```
```rb
# In your views add the version name to all <attachment>_url calls.
user.avatar_url(:thumb)
```

Note that you should deploy both of these changes at once, because the
`<attachment>_url` method will fail if there are versions generated but no
version name was passed in. If a version name was passed in but versions aren't
generated yet (which will be the case here), it will just return the
unprocessed file URL.

Afterwards you should run a script which reprocesses the versions for existing
files:

```rb
User.paged_each do |user|
  attacher, attachment = user.avatar_attacher, user.avatar
  if attacher.stored? && !attachment.is_a?(Hash)
    file = some_processing(attachment.download)
    thumb = attacher.store!(file, version: :thumb)
    attacher.swap({original: avatar, thumb: thumb})
  end
end
```

## Reprocessing a single version

The simplest scenario is where you need to regenerate an existing version.
First you need to change and deploy your updated processing code, and
afterwards you can run a script like this on your production database:

```rb
User.paged_each do |user|
  attacher, attachment = user.avatar_attacher, user.avatar
  if attacher.stored?
    file = some_processing(attachment[:original].download)
    thumb = attachment[:thumb].replace(thumb)
    attacher.swap(attachment.merge(thumb: thumb))
  end
end
```

### Adding a new version

When adding a new version to a production app, first add it to the list and
update your processing code to generate it, and deploy it:

```rb
class ImageUploader < Shrine
  # ...

  process(:store) do |io, context|
    # ...
    new = some_processing(io.download, *args)
    {small: small, medium: medium, new: new} # we generate the ":new" version
  end
end
```

After you've deployed this change, you should run a script that will generate
the new version for all existing records:

```rb
User.paged_each do |user|
  attacher, attachment = user.avatar_attacher, user.avatar
  if attacher.stored? && !attachment[:new]
    file = some_processing(attachment[:original].download, *args)
    new = attacher.store!(file, version: :new)
    attacher.swap(attachment.merge(new: new))
  end
end
```

After you've run this script on your production database, all records should
have the new version, and now you should be able to safely update your app to
use it.

### Removing a version

Before removing a version, you first need to update your processing to not
generate it (but keep the version name in the list), as well as update your app
not to use the new version, and deploy that code. After you've done that, you
can run a script which removes that version:

```rb
old_versions = []

User.paged_each do |user|
  attacher, attachment = user.avatar_attacher, user.avatar
  if attacher.stored? && attachment[:old_version]
    old_version = attachment.delete(:old_version)
    swapped = attacher.swap(attachment)
    old_versions << old_version if swapped
  end
end

if old_versions.any?
  uploader = old_versions.first.uploader
  uploader.delete(old_versions)
end
```

After the script has finished, you should be able to safely remove the version
name from the list.

## Reprocessing all versions

If you made a lot of changes to versions, it might make sense to simply
regenerate all versions. After you've deployed the change in processing, you
can run a script which updates existing records:

```rb
User.paged_each do |user|
  if user.avatar_attacher.stored?
    # assuming your largest version is named ":original"
    user.update(avatar: user.avatar[:original])
  end
end
```
