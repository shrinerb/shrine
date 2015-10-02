class Shrine
  module Plugins
    module BackgroundDelete
      def self.configure(uploader, &block)
        uploader.opts[:delete] = block
      end

      module AttacherMethods
        def delete!(uploaded_file, phase:)
          delete = shrine_class.opts[:delete]
          delete.call(uploaded_file, context.merge(phase: phase))
        end
      end
    end

    register_plugin(:background_delete, BackgroundDelete)
  end
end
