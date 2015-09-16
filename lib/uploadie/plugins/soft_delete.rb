class Uploadie
  module Plugins
    module SoftDelete
      def self.configure(uploader, replaced: false)
        uploader.opts[:soft_delete_replaced] = replaced
      end

      module AttacherMethods
        def destroy
        end

        def delete!(uploaded_file)
          if uploadie_class.opts[:soft_delete_replaced]
            # don't delete
          else
            super
          end
        end
      end
    end

    register_plugin(:soft_delete, SoftDelete)
  end
end
