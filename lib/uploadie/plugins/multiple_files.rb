class Uploadie
  module Plugins
    module MultipleFiles
      module InstanceMethods
        def upload(io, type = nil)
          if io.is_a?(Array)
            if type.is_a?(Array)
              io.zip(type).map { |io, type| super(io, type) }
            else
              io.map { |io| super(io, type) }
            end
          else
            super
          end
        end

        def store(io, type = nil)
          if io.is_a?(Array)
            io.zip(type).map { |io, type| super(io, type) }
          else
            super
          end
        end
      end
    end

    register_plugin(:multiple_files, MultipleFiles)
  end
end
