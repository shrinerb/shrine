class Shrine
  module Plugins
    module BackgroundDelete
      def self.configure(uploader, delete:)
        uploader.opts[:delete] = delete
      end

      module AttacherMethods
        def delete!(uploaded_file, phase:)
          shrine_class.opts[:delete].call(uploaded_file, context.merge(phase: phase))
        end
      end
    end

    register_plugin(:background_delete, BackgroundDelete)
  end
end
