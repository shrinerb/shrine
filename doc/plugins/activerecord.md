# Active Record

The [`activerecord`][activerecord] plugin extends the "attachment" interface
with support for ActiveRecord.

```rb
plugin :activerecord
```

## Callbacks

Now the attachment module will add additional callbacks to the model:

* "before save" – Used by the `recache` plugin.
* "after commit" (save) – Promotes the attachment, deletes replaced ones.
* "after commit" (destroy) – Deletes the attachment.

Note that ActiveRecord versions 3.x and 4.x have errors automatically silenced
in hooks, which can make debugging more difficult, so it's recommended that you
enable errors:

```rb
# This is the default in ActiveRecord 5
ActiveRecord::Base.raise_in_transactional_callbacks = true
```

If you want to put promoting/deleting into a background job, see the
`backgrounding` plugin.

Since attaching first saves the record with a cached attachment, then saves
again with a stored attachment, you can detect this in callbacks:

```rb
class User < ActiveRecord::Base
  include ImageUploader::Attachment.new(:avatar)

  before_save do
    if avatar_data_changed? && avatar_attacher.cached?
      # cached
    elsif avatar_data_changed? && avatar_attacher.stored?
      # promoted
    end
  end
end
```

Note that ActiveRecord currently has a [bug with transaction callbacks], so if
you have any "after commit" callbacks, make sure to include Shrine's attachment
module *after* they have all been defined.

If you don't want the attachment module to add any callbacks to the model, and
would instead prefer to call these actions manually, you can disable callbacks:

```rb
plugin :activerecord, callbacks: false
```

## Validations

Additionally, any Shrine validation errors will be added to ActiveRecord's
errors upon validation. Note that Shrine validation messages don't have to be
strings, they can also be symbols or symbols and options, which allows them to
be internationalized together with other ActiveRecord validation messages.

```rb
class MyUploader < Shrine
  plugin :validation_helpers

  Attacher.validate do
    validate_max_size 256 * 1024**2, message: ->(max) { [:max_size, max: max] }
  end
end
```

If you want to validate presence of the attachment, you can do it directly on
the model.

```rb
class User < ActiveRecord::Base
  include ImageUploader::Attachment.new(:avatar)
  validates_presence_of :avatar
end
```

If don't want the attachment module to merge file validations errors into
model errors, you can disable it:

```rb
plugin :activerecord, validations: false
```

[activerecord]: /lib/shrine/plugins/activerecord.rb
[bug with transaction callbacks]: https://github.com/rails/rails/issues/14493
