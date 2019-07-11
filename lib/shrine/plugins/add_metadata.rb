# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/add_metadata.md] on GitHub.
    #
    # [doc/plugins/add_metadata.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/add_metadata.md
    module AddMetadata
      def self.configure(uploader)
        uploader.opts[:metadata] ||= []
      end

      module ClassMethods
        def add_metadata(name = nil, &block)
          opts[:metadata] << [name, block]

          metadata_method(name) if name
        end

        def metadata_method(*names)
          names.each { |name| _metadata_method(name) }
        end

        private

        def _metadata_method(name)
          self::UploadedFile.send(:define_method, name) do
            metadata[name.to_s]
          end
        end
      end

      module InstanceMethods
        def extract_metadata(io, context = {})
          metadata = super
          context  = context.merge(metadata: metadata)

          extract_custom_metadata(io, context)

          metadata
        end

        private

        def extract_custom_metadata(io, context)
          opts[:metadata].each do |name, block|
            metadata = {}

            if name
              metadata[name.to_s] = result
            else
              metadata.merge!(result) if result
            end

            # convert symbol keys to strings
            metadata.keys.each do |key|
              metadata[key.to_s] = metadata.delete(key) if key.is_a?(Symbol)
            end

            context[:metadata].merge!(metadata)

            # rewind between metadata blocks
            io.rewind
          end
        end
      end
    end

    register_plugin(:add_metadata, AddMetadata)
  end
end
