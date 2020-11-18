# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/add_metadata
    module AddMetadata
      def self.configure(uploader)
        uploader.opts[:add_metadata] ||= { definitions: [] }
      end

      module ClassMethods
        def add_metadata(name = nil, **options, &block)
          opts[:add_metadata][:definitions] << [name, options, block]

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
        def extract_metadata(io, **options)
          metadata = super

          extract_custom_metadata(io, **options, metadata: metadata)

          metadata
        end

        private

        def extract_custom_metadata(io, **options)
          opts[:add_metadata][:definitions].each do |name, definition_options, block|
            result = instance_exec(io, **options, &block)

            if result.nil? && definition_options[:skip_nil]
              # Do not store this metadata
            elsif name
              options[:metadata].merge! name.to_s => result
            else
              options[:metadata].merge! result.transform_keys(&:to_s) if result
            end

            # rewind between metadata blocks
            io.rewind
          end
        end
      end

      module AttacherMethods
        def add_metadata(new_metadata, &block)
          file!.add_metadata(new_metadata, &block)
          set(file) # trigger model write
        end
      end

      module FileMethods
        def add_metadata(new_metadata, &block)
          @metadata = @metadata.merge(new_metadata, &block)
        end
      end
    end

    register_plugin(:add_metadata, AddMetadata)
  end
end
