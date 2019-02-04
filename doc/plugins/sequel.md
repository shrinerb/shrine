# Sequel

The `sequel` plugin extends the "attachment" interface with support for Sequel.

```rb
plugin :sequel
```

## Callbacks

Now the attachment module will add additional callbacks to the model:

* "before save" – Used by the `recache` plugin.
* "after commit" (save) – Promotes the attachment, deletes replaced ones.
* "after commit" (destroy) – Deletes the attachment.

If you want to put promoting/deleting into a background job, see the
`backgrounding` plugin.

Since attaching first saves the record with a cached attachment, then saves
again with a stored attachment, you can detect this in callbacks:

```rb
class User < Sequel::Model
  include ImageUploader::Attachment.new(:avatar)

  def before_save
    super

    if changed_columns.include?(:avatar) && avatar_attacher.cached?
      # cached
    elsif changed_columns.include?(:avatar) && avatar_attacher.stored?
      # promoted
    end
  end
end
```

If you don't want the attachment module to add any callbacks to the model, and
would instead prefer to call these actions manually, you can disable callbacks:

```rb
plugin :sequel, callbacks: false
```

## Validations

Additionally, any Shrine validation errors will added to Sequel's errors upon
validation. Note that if you want to validate presence of the attachment, you
can do it directly on the model.

```rb
class User < Sequel::Model
  include ImageUploader::Attachment.new(:avatar)
  validates_presence_of :avatar
end
```

If don't want the attachment module to merge file validations errors into model
errors, you can disable it:

```rb
plugin :sequel, validations: false
```
