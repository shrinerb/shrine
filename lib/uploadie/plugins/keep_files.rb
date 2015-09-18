class Uploadie
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
          super unless uploadie_class.keep?(:destroyed)
        end

        def delete!(uploaded_file)
          if store.uploaded?(uploaded_file)
            super unless uploadie_class.keep?(:replaced)
          else
            super
          end
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
