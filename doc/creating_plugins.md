# Creating a new plugin

Shrine has a lot of plugins built-in, but you can also easily create your own.
Simply put, a plugin is a module:

```rb
module MyPlugin
  # ...
end

Shrine.plugin MyPlugin
```

If you would like to load plugins with a symbol, like you already load plugins
that ship with Shrine, you need to put the plugin in
`shrine/plugins/my_plugin.rb` in the load path, and register it:

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
    def upload(io, context)
      time = Time.now
      result = super
      duration = Time.now - time
      puts "Upload duration: #{duration}s"
    end
  end
end
```

Notice that we can call `super` to get the original behaviour. In addition to
these modules, you can also make your plugin configurable:

```rb
Shrine.plugin :my_plugin, foo: "bar"
```

You can do this my adding a `.configure` method to your plugin, which will be
given any passed in arguments or blocks. Typically you'll want to save these
options into Shrine's `opts`, so that you can access them inside of Shrine's
methods.

```rb
module MyPlugin
  def self.configure(uploader, options = {})
    uploader # The uploader class which called `.plugin`
    uploader.opts[:my_plugin_options] = options
  end

  module InstanceMethods
    def foo
      opts[:my_plugin_options] #=> {foo: "bar"}
    end
  end
end
```

If your plugin depends on other plugins, you can load them inside of
`.load_dependencies` (which is given the same arguments as `.configure`):

```rb
module MyPlugin
  def self.load_dependencies(uploader, *)
    uploader.plugin :versions # depends on the versions plugin
  end
end
```
