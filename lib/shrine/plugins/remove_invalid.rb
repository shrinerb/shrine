# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/remove_invalid.md] on GitHub.
    #
    # [doc/plugins/remove_invalid.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/remove_invalid.md
    module RemoveInvalid
      def self.load_dependencies(uploader)
        uploader.plugin :validation
      end

      module AttacherMethods
        def change(*)
          super
        ensure
          revert_change if errors.any?
        end

        private

        def revert_change
          destroy
          set @previous.file
          remove_instance_variable(:@previous)
        end
      end
    end

    register_plugin(:remove_invalid, RemoveInvalid)
  end
end
