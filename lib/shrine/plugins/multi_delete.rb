# frozen_string_literal: true

Shrine.deprecation("The multi_delete plugin is deprecated and will be removed in Shrine 3.")

class Shrine
  module Plugins
    module MultiDelete
      module InstanceMethods
        private

        # Adds the ability to upload multiple files, leveraging the underlying
        # storage's potential multi delete capability.
        def _delete(uploaded_file, context)
          if uploaded_file.is_a?(Array)
            if storage.respond_to?(:multi_delete)
              storage.multi_delete(uploaded_file.map(&:id))
            else
              uploaded_file.each { |file| _delete(file, context) }
            end
          else
            super
          end
        end
      end
    end

    register_plugin(:multi_delete, MultiDelete)
  end
end
