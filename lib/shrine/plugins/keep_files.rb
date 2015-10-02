class Shrine
  module Plugins
    module KeepFiles
      def self.configure(uploader, destroyed: nil, replaced: nil, cached: nil)
        uploader.opts[:keep_files] = []
        uploader.opts[:keep_files] << :destroyed if destroyed
        uploader.opts[:keep_files] << :replaced if replaced
        uploader.opts[:keep_files] << :cached if cached
      end

      module ClassMethods
        def keep?(type)
          opts[:keep_files].include?(type)
        end

        def delete(io, context)
          case context[:phase]
          when :promote then super unless keep?(:cached)
          when :replace then super unless keep?(:replaced)
          when :destroy then super unless keep?(:destroyed)
          else
            super
          end
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
