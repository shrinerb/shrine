require "shrine/plugins/backgrounding"
Shrine::Plugins.register_plugin(:background_helpers, Shrine::Plugins::Backgrounding)
