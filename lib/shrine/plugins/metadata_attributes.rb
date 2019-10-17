# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/metadata_attributes
    module MetadataAttributes
      def self.load_dependencies(uploader, *)
        uploader.plugin :entity
      end

      def self.configure(uploader, **opts)
        uploader.opts[:metadata_attributes] ||= {}
        uploader.opts[:metadata_attributes].merge!(opts)
      end

      module AttacherClassMethods
        def metadata_attributes(mappings = nil)
          if mappings
            shrine_class.opts[:metadata_attributes].merge!(mappings)
          else
            shrine_class.opts[:metadata_attributes]
          end
        end
      end

      module AttacherMethods
        def column_values
          super.merge(metadata_attributes)
        end

        private

        def metadata_attributes
          values = {}

          self.class.metadata_attributes.each do |source, destination|
            metadata_attribute = destination.is_a?(Symbol) ? :"#{name}_#{destination}" : :"#{destination}"

            next unless record.respond_to?(metadata_attribute)

            values[metadata_attribute] = file && file.metadata[source.to_s]
          end

          values
        end
      end
    end

    register_plugin(:metadata_attributes, MetadataAttributes)
  end
end
