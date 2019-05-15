# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/parsed_json.md] on GitHub.
    #
    # [doc/plugins/parsed_json.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/parsed_json.md
    module ParsedJson
      module AttacherMethods
        def assign(value, **options)
          if value.is_a?(Hash) && parsed_json?(value)
            assign(value.to_json, **options)
          else
            super
          end
        end

        private

        def parsed_json?(value)
          (value.key?('id') || value.key?(:id)) &&
          (value.key?('storage') || value.key?(:storage))
        end
      end
    end

    register_plugin(:parsed_json, ParsedJson)
  end
end
