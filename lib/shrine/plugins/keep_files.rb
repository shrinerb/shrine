class Shrine
  module Plugins
    module KeepFiles
      def self.configure(uploader, destroyed: nil, replaced: nil)
        uploader.opts[:keep_files] = []
        uploader.opts[:keep_files] << :destroyed if destroyed
        uploader.opts[:keep_files] << :replaced if replaced
      end

      module ClassMethods
        def keep?(type)
          opts[:keep_files].include?(type)
        end
      end

      module AttacherMethods
        def destroy
          super unless shrine_class.keep?(:destroyed)
        end

        def replace
          super unless shrine_class.keep?(:replaced)
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
