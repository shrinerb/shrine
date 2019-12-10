# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/remove_invalid
    module RemoveInvalid
      def self.load_dependencies(uploader)
        uploader.plugin :validation
      end

      module AttacherMethods
        def validate(*)
          super
        ensure
          deassign if errors.any?
        end

        private

        def deassign
          destroy

          if changed?
            load_data @previous.data
            remove_instance_variable(:@previous)
          else
            load_data nil
          end
        end
      end
    end

    register_plugin(:remove_invalid, RemoveInvalid)
  end
end
