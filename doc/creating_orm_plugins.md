# Writing an ORM Plugin

This guide explains some conventions for writing Shrine plugins that integrate
with database libraries such as Active Record, Sequel, ROM, Mongoid. It assumes
you've read the [Writing a Plugin] guide.

## Attachment

If your database library uses the [Active Record pattern], it's recommended to
load the [`model`][model] plugin as a dependency. Otherwise if it uses the
[Repository pattern], you can load the [`entity`][entity] plugin as a
dependency.

If you want to add ORM-specific integration when `Shrine::Attachment` is
included into a model/entity, it's recommended to do this in the `included`
hook, so that you can perform this logic only for models/entities that belong
to that ORM.

```rb
module AttachmentMethods
  def included(model)
    super

    return unless model < YourOrm::Model

    # ...
  end
end
```

## Attacher

### Persistence

It's recommended to implement an `Attacher#persist` method which persists
the attached file to the record. This way other 3rd-party plugins can use
`Attacher#persist` and know it will do the right thing regardless of which
ORM plugin is used.

### Atomic promotion & persistence

When using [`backgrounding`][backgrounding] plugin, it's useful to be able to
make promotion/persistence atomic. The [`atomic_helpers`][atomic_helpers]
plugin provides the abstract interface, and in your ORM plugin you can provide
wrappers.

See the [`activerecord`][activerecord]/[`sequel`][sequel] plugin source code on
how this integration should look like.

### With other ORM plugins

It's recommended to prefix each of the above methods with the name of the
database library, and make non-prefixed versions aliases. That way the user
can always specify from which ORM plugin they're calling a certain method, even
when multiple ORM plugins are loaded simultaneously.

This is useful if the user is using multiple ORMs in a single application, or
if they're transitioning from one ORM to another.

[Writing a Plugin]: /doc/creating_plugins.md#readme
[Active Record pattern]: https://www.martinfowler.com/eaaCatalog/activeRecord.html
[model]: /doc/plugins/model.md#readme
[Repository pattern]: https://martinfowler.com/eaaCatalog/repository.html
[backgrounding]: /doc/plugins/backgrounding.md#readme
[atomic_helpers]: /doc/plugins/atomic_helpers.md#readme
[activerecord]: /lib/shrine/plugins/activerecord.rb
[sequel]: /lib/shrine/plugins/sequel.rb
