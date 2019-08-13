# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/metadata_attributes.md] on GitHub.
    #
    # [doc/plugins/metadata_attributes.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/metadata_attributes.md
    module MetadataAttributes
      def self.load_dependencies(uploader, *)
        uploader.plugin :entity
      end

      def self.configure(uploader, mappings = {})
        uploader.opts[:metadata_attributes] ||= { mappings: {} }
        uploader.opts[:metadata_attributes][:mappings].merge!(mappings)
      end

      module AttacherClassMethods
        def metadata_attributes(mappings)
          shrine_class.opts[:metadata_attributes][:mappings].merge!(mappings)
        end
      end

      module AttacherMethods
        def column_values
          values = super

          shrine_class.opts[:metadata_attributes][:mappings].each do |source, destination|
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
