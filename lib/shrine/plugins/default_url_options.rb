# frozen_string_literal: true

Shrine.deprecation("The default_url_options plugin has been renamed to url_options, so `plugin :default_url_options` should be replaced with `plugin :url_options`. The default_url_options alias will be removed in Shrine 4.")

require "shrine/plugins/url_options"

Shrine::Plugins.register_plugin(:default_url_options, Shrine::Plugins::UrlOptions)
