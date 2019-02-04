# frozen_string_literal: true

class Shrine
  module Plugins
    module ParsedJson
      module AttacherMethods
        def assign(value)
          if value.is_a?(Hash) && parsed_json?(value)
            assign(value.to_json)
          else
            super
          end
        end

        private

        def parsed_json?(hash)
          hash.keys.any? { |key| key.is_a?(String) }
        end
      end
    end

    register_plugin(:parsed_json, ParsedJson)
  end
end
