class Shrine
  module Plugins
    module BackgroundHelpers
      module AttacherClassMethods
        def delete(&block)
          shrine_class.opts[:background_delete] = block
        end

        def promote(&block)
          shrine_class.opts[:background_promote] = block
        end
      end

      module AttacherMethods
        def _promote
          if background_promote = shrine_class.opts[:background_promote]
            instance_exec(get, &background_promote) if promote?(get)
          else
            super
          end
        end

        private

        def delete!(uploaded_file, phase:)
          if background_delete = shrine_class.opts[:background_delete]
            instance_exec(uploaded_file, phase: phase, &background_delete)
          else
            super
          end
        end
      end
    end

    register_plugin(:background_helpers, BackgroundHelpers)
  end
end
