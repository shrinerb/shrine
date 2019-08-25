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

To help define persistence methods on the `Attacher` according to the
convention, load the `:_persistence` plugin as a dependency:

```rb
module Shrine::Plugins::Raptor
  def self.load_dependencies(uploader, **)
    # ...
    uploader.plugin :_persistence, plugin: self
  end
  # ...
end
```

This will define the following attacher methods:

* `Attacher#persist`
* `Attacher#atomic_persist`
* `Attacher#atomic_promote`

For those methods to work, we'll need to implement the following methods:

* `Attacher#<library>_persist`
* `Attacher#<library>_reload`
* `Attacher#<library>?`

```rb
module Shrine::Plugins::Raptor
  # ...
  module AttacherMethods
    # ...
    private

    def raptor_persist
      # persist attached file to the record
    end

    def raptor_reload
      # yield reloaded record (see atomic_helpers plugin)
    end

    def raptor?
      # returns whether current model/entity belongs to Raptor
    end
  end
end
```

[Writing a Plugin]: /doc/creating_plugins.md#readme
[Active Record pattern]: https://www.martinfowler.com/eaaCatalog/activeRecord.html
[model]: /doc/plugins/model.md#readme
[entity]: /doc/plugins/entity.md#readme
[Repository pattern]: https://martinfowler.com/eaaCatalog/repository.html
[backgrounding]: /doc/plugins/backgrounding.md#readme
[atomic_helpers]: /doc/plugins/atomic_helpers.md#readme
[activerecord]: /lib/shrine/plugins/activerecord.rb
[sequel]: /lib/shrine/plugins/sequel.rb
