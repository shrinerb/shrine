# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/metadata_attributes.md] on GitHub.
    #
    # [doc/plugins/metadata_attributes.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/metadata_attributes.md
    module MetadataAttributes
      def self.configure(uploader, mappings = {})
        uploader.opts[:metadata_attributes_mappings] ||= {}
        uploader.opts[:metadata_attributes_mappings].merge!(mappings)
      end

      module AttacherClassMethods
        def metadata_attributes(mappings)
          shrine_class.opts[:metadata_attributes_mappings].merge!(mappings)
        end
      end

      module AttacherMethods
        def assign(value)
          super
          cached_file = get

          shrine_class.opts[:metadata_attributes_mappings].each do |source, destination|
            attribute_name = destination.is_a?(Symbol) ? :"#{name}_#{destination}" : :"#{destination}"

            next unless record.respond_to?(:"#{attribute_name}=")

            if cached_file
              record.send(:"#{attribute_name}=", cached_file.metadata[source.to_s])
            else
              record.send(:"#{attribute_name}=", nil)
            end
          end
        end
      end
    end

    register_plugin(:metadata_attributes, MetadataAttributes)
  end
end
