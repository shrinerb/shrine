class Shrine
  module Plugins
    # The `add_metadata` plugin provides a convenient method for extracting and
    # adding custom metadata values.
    #
    #     plugin :add_metadata
    #
    #     add_metadata :pages do |io, context|
    #       PDF::Reader.new(io.path).page_count
    #     end
    #
    # The above will add "pages" to the metadata hash, and also create the
    # `#pages` reader method on Shrine::UploadedFile.
    #
    #     document.metadata["pages"]
    #     # or
    #     document.pages
    #
    # You can also extract multiple metadata values at once, by using
    # `add_metadata` without an argument.
    #
    #     add_metadata do |io, context|
    #       movie = FFMPEG::Movie.new(io.path)
    #
    #       { "duration"   => movie.duration,
    #         "bitrate"    => movie.bitrate,
    #         "resolution" => movie.resolution,
    #         "frame_rate" => movie.frame_rate }
    #     end
    #
    # In this case Shrine won't automatically create reader methods for the
    # extracted metadata on Shrine::UploadedFile, but you can create them via
    # `metadata_method`.
    #
    #     metadata_method :duration, :bitrate, :resolution, :frame_rate
    module AddMetadata
      def self.configure(uploader)
        uploader.opts[:metadata] = []
      end

      module ClassMethods
        def add_metadata(name = nil, &block)
          if name
            opts[:metadata] << _metadata_proc(name, &block)
            metadata_method(name)
          else
            opts[:metadata] << block
          end
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

        def _metadata_proc(name, &block)
          proc do |io, context|
            value = instance_exec(io, context, &block)
            {name.to_s => value} unless value.nil?
          end
        end
      end

      module InstanceMethods
        def extract_metadata(io, context)
          metadata = super

          opts[:metadata].each do |metadata_block|
            custom_metadata = instance_exec(io, context, &metadata_block)
            io.rewind
            metadata.merge!(custom_metadata) unless custom_metadata.nil?
          end

          metadata
        end
      end
    end

    register_plugin(:add_metadata, AddMetadata)
  end
end
