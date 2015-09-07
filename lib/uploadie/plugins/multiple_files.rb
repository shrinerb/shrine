class Uploadie
  module Plugins
    module MultipleFiles
      module InstanceMethods
        def upload(io, context = {})
          if io.is_a?(Array)
            upload_multiple(io, context) { |io, context| super(io, context) }
          else
            super
          end
        end

        def store(io, context = {})
          if io.is_a?(Array)
            upload_multiple(io, context) { |io, context| super(io, context) }
          else
            super
          end
        end

        private

        def upload_multiple(ios, context)
          if context.is_a?(Array)
            ios.zip(context).map { |io, context| yield(io, context) }
          else
            ios.map { |io| yield(io, context) }
          end
        end
      end
    end

    register_plugin(:multiple_files, MultipleFiles)
  end
end
