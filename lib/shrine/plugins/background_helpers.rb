Shrine.deprecation("The background_helpers plugin has been renamed to \"backgrounding\". Loading the plugin through \"background_helpers\" will stop working in Shrine 3.")
require "shrine/plugins/backgrounding"
Shrine::Plugins.register_plugin(:background_helpers, Shrine::Plugins::Backgrounding)
