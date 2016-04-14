warn "The restore_cached Shrine plugin has been renamed to \"restore_cached_data\". Loading the plugin through \"restore_cached\" will not work in Shrine 2."
require "shrine/plugins/restore_cached_data"
Shrine::Plugins.register_plugin(:restore_cached, Shrine::Plugins::RestoreCachedData)
