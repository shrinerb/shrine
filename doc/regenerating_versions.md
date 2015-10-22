# Regenerating versions

While your app is serving uploads in production, you may realize that you want
to change how your attachment's versions are generated. This means that, in
addition to changing you processing code, you also need to reprocess the
existing attachments. Depending on the magnitude and the nature of the change,
you can take different steps on doing that.

## Regenerating a specific version

The simplest scenario is where you need to regenerate a specific version. After
you change your processing code, this is how you would regenerate a specific
version (in Sequel):

```rb
Shrine.plugin :migration_helpers

User.paged_each do |user|
  user.update_avatar do |avatar|
    file = some_processing(avatar[:thumb].download)
    avatar.merge(thumb: avatar[:thumb].replace(file))
  end
end
```

In a similar way you would add a new version or remove an existing one.

## Regenerating all versions

If you made a lot of changes to versions, it might make sense to simply
regenerate all versions. You would typically use a "base" version to regenerate
the other versions from:

```rb
User.paged_each do |user|
  user.update(avatar: user.avatar[:original])
end
```
