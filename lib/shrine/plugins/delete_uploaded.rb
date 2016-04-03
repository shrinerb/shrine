warn "The delete_uploaded Shrine plugin has been renamed to \"delete_raw\". Loading the plugin through \"delete_uploaded\" will not work in Shrine 2."
require "shrine/plugins/delete_raw"
Shrine::Plugins.register_plugin(:delete_uploaded, Shrine::Plugins::DeleteRaw)
