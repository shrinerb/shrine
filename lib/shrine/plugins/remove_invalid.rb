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
            @previous = nil
          else
            load_data nil
          end
on
          # `load_data` bypasses `Attacher#set`, so when the model plugin is
          # loaded the record attribute needs to be synced manually.
          write if respond_to?(:write)
        end
      end
    end

    register_plugin(:remove_invalid, RemoveInvalid)
  end
end
