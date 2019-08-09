# Writing an Persistence Plugin

This guide explains some conventions for writing Shrine plugins that integrate
with persistence libraries such as Active Record, Sequel, ROM and Mongoid. It
assumes you've read the [Writing a Plugin] guide.

Let's say we're writing a plugin for a persistence library called "Raptor":

```rb
# lib/shrine/plugins/raptor.rb

require "raptor"

class Shrine
  module Plugins
    module Raptor
      # ...
    end

    register_plugin(:raptor, Raptor)
  end
end
```

## Attachment

If your database library uses the [Active Record pattern], it's recommended to
load the [`model`][model] plugin as a dependency.

```rb
module Shrine::Plugins::Raptor
  def self.load_dependencies(uploader, **)
    uploader.plugin :model # for Active Record pattern
  end
  # ...
end
```

Otherwise if it uses the [Repository pattern], you can load the
[`entity`][entity] plugin as a dependency.

```rb
module Shrine::Plugins::Raptor
  def self.load_dependencies(uploader, **)
    uploader.plugin :entity # for Repository pattern
  end
  # ...
end
```

If you want to add library-specific integration when `Shrine::Attachment` is
included into a model/entity, it's recommended to do this in the `included`
hook, so that you can perform this logic only for models/entities that belong
to that persistence library.

```rb
module Shrine::Plugins::Raptor
  # ...
  module AttachmentMethods
    def included(klass)
      super

      return unless klass < ::Raptor::Model

      # library specific integration
    end
  end
  # ...
end
```

## Attacher

### Persistence

It's recommended to implement an `Attacher#persist` method which persists
the attached file to the record.

```rb
module Shrine::Plugins::Raptor
  # ...
  module AttacherMethods
    # ...
    def persist(...)
      # persist attachment data
    end
    # ...
  end
  # ...
end
```

This way other 3rd-party plugins can use `Attacher#persist` and know it will do
the right thing regardless of which persistence plugin is used.

### Atomic promotion & persistence

When using [`backgrounding`][backgrounding] plugin, it's useful to be able to
make promotion/persistence atomic. The [`atomic_helpers`][atomic_helpers]
plugin provides the abstract interface, and in your persistence plugin you can
provide wrappers.

```rb
module Shrine::Plugins::Raptor
  def self.load_dependencies(uploader, **)
    # ...
    uploader.plugin :atomic_helpers
  end
  # ...
  module AttacherMethods
    # ...
    def atomic_promote(...)
      # call #abstract_atomic_promote from atomic_helpers plugin
    end

    def atomic_persist(...)
      # call #abstract_atomic_persist from atomic_helpers plugin
    end
    # ...
  end
  # ...
end
```

See the [`activerecord`][activerecord]/[`sequel`][sequel] plugin source code on
how this integration should look like.

### With other persistence plugins

It's recommended to prefix each of the above methods with the name of the
database library, and make non-prefixed versions aliases.

```rb
module Shrine::Plugins::Raptor
  # ...
  module AttacherMethods
    # ...
    def raptor_atomic_promote(...)
      # ...
    end
    alias atomic_promote raptor_atomic_promote

    def raptor_atomic_persist(...)
      # ...
    end
    alias atomic_persist raptor_atomic_persist

    def raptor_persist(...)
      # ...
    end
    alias persist raptor_persist
    # ...
  end
  # ...
end
```

That way the user can always specify from which persistence plugin they're
calling a certain method, even when multiple persistence plugins are loaded
simultaneously. The latter can be the case if the user is using multiple
database libraries in a single application, or if they're transitioning from
one library to another.

[Writing a Plugin]: /doc/creating_plugins.md#readme
[Active Record pattern]: https://www.martinfowler.com/eaaCatalog/activeRecord.html
[model]: /doc/plugins/model.md#readme
[entity]: /doc/plugins/entity.md#readme
[Repository pattern]: https://martinfowler.com/eaaCatalog/repository.html
[backgrounding]: /doc/plugins/backgrounding.md#readme
[atomic_helpers]: /doc/plugins/atomic_helpers.md#readme
[activerecord]: /lib/shrine/plugins/activerecord.rb
[sequel]: /lib/shrine/plugins/sequel.rb
