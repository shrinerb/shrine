---
id: creating-plugins
title: Writing a Plugin
---

Shrine has a lot of plugins built-in, but you can use Shrine's plugin system to
create your own.

## Definition

Simply put, a plugin is a module:

```rb
module MyPlugin
  # ...
end

Shrine.plugin MyPlugin
```

If you would like to load plugins with a symbol (like you already do with
plugins that ship with Shrine), you need to put the plugin in
`shrine/plugins/my_plugin.rb` in your load path and register it:

```rb
# shrine/plugins/my_plugin.rb
class Shrine
  module Plugins
    module MyPlugin
      # ...
    end

    register_plugin(:my_plugin, MyPlugin)
  end
end
```
```rb
Shrine.plugin :my_plugin
```

## Methods

The way to make plugins actually extend Shrine's core classes is by defining
special modules inside the plugin. Here's a list of all "special" modules:

```rb
InstanceMethods        # gets included into `Shrine`
ClassMethods           # gets extended into `Shrine`
AttachmentMethods      # gets included into `Shrine::Attachment`
AttachmentClassMethods # gets extended into `Shrine::Attachment`
AttacherMethods        # gets included into `Shrine::Attacher`
AttacherClassMethods   # gets extended into `Shrine::Attacher`
FileMethods            # gets included into `Shrine::UploadedFile`
FileClassMethods       # gets extended into `Shrine::UploadedFile`
```

For example, this is how you would make your plugin add some logging to
uploading:

```rb
module MyPlugin
  module InstanceMethods
    def upload(io, **options)
      time = Time.now
      result = super
      duration = Time.now - time
      puts "Upload duration: #{duration}s"
    end
  end
end
```

Notice that we can call `super` to get the original behaviour.

## Configuration

You'll likely want to make your plugin configurable. You can do that by
overriding the `.configure` class method and storing received options into
`Shrine.opts`:

```rb
module MyPlugin
  def self.configure(uploader, **opts)
    uploader.opts[:my_plugin] ||= {}
    uploader.opts[:my_plugin].merge!(opts)
  end

  module InstanceMethods
    def upload(io, **options)
      opts[:my_plugin] #=> { ... }
      # ...
    end
  end
end
```

Users can now pass these configuration options when loading your plugin:

```rb
Shrine.plugin :my_plugin, foo: "bar"
```

## Dependencies

If your plugin depends on other plugins, you can load them inside of
`.load_dependencies`:

```rb
module MyPlugin
  def self.load_dependencies(uploader, **opts)
    uploader.plugin :derivatives # depends on the derivatives plugin
  end
end
```

The dependencies will get loaded before your plugin, allowing you to override
methods of your dependencies in your method modules.

The same configuration options passed to `.configure` are passed to
`.load_dependencies` as well.
