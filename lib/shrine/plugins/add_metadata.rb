# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/add_metadata.md] on GitHub.
    #
    # [doc/plugins/add_metadata.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/add_metadata.md
    module AddMetadata
      def self.configure(uploader)
        uploader.opts[:add_metadata_definitions] ||= []
      end

      module ClassMethods
        def add_metadata(name = nil, &block)
          opts[:add_metadata_definitions] << [name, block]

          metadata_method(name) if name
        end

        def metadata_method(*names)
          names.each { |name| _metadata_method(name) }
        end

        private

        def _metadata_method(name)
          FileMethods.send(:define_method, name) do
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
          opts[:add_metadata_definitions].each do |name, block|
            result = instance_exec(io, context, &block)

            if name
              context[:metadata].merge! name.to_s => result
            else
              context[:metadata].merge! result.transform_keys(&:to_s) if result
            end

            # rewind between metadata blocks
            io.rewind
          end
        end
      end

      module FileMethods
        # methods will be dynamically defined here through `Shrine.add_metadata`
      end
    end

    register_plugin(:add_metadata, AddMetadata)
  end
end
