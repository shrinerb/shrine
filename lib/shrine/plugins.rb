# frozen_string_literal: true

class Shrine
  # Module in which all Shrine plugins should be stored. Also contains logic
  # for registering and loading plugins.
  module Plugins
    @plugins = {}

    # If the registered plugin already exists, use it. Otherwise, require it
    # and return it. This raises a LoadError if such a plugin doesn't exist,
    # or a Shrine::Error if it exists but it does not register itself
    # correctly.
    def self.load_plugin(name)
      unless plugin = @plugins[name]
        require "shrine/plugins/#{name}"
        raise Error, "plugin #{name} did not register itself correctly in Shrine::Plugins" unless plugin = @plugins[name]
      end
      plugin
    end

    # Delegate call to the plugin in a way that works across Ruby versions.
    def self.load_dependencies(plugin, uploader, *args, **kwargs, &block)
      return unless plugin.respond_to?(:load_dependencies)

      if kwargs.any?
        plugin.load_dependencies(uploader, *args, **kwargs, &block)
      else
        plugin.load_dependencies(uploader, *args, &block)
      end
    end

    # Delegate call to the plugin in a way that works across Ruby versions.
    def self.configure(plugin, uploader, *args, **kwargs, &block)
      return unless plugin.respond_to?(:configure)

      if kwargs.any?
        plugin.configure(uploader, *args, **kwargs, &block)
      else
        plugin.configure(uploader, *args, &block)
      end
    end

    # Register the given plugin with Shrine, so that it can be loaded using
    # `Shrine.plugin` with a symbol. Should be used by plugin files. Example:
    #
    #     Shrine::Plugins.register_plugin(:plugin_name, PluginModule)
    def self.register_plugin(name, mod)
      @plugins[name] = mod
    end
  end
end
