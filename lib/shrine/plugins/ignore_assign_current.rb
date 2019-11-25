# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/ignore_assign_current
    module IgnoreAssignCurrent
      module AttacherMethods
        def assign(value, **options)
          if value.is_a?(String) && !value.empty? || value.is_a?(Hash)
            return if uploaded_file(value) == file
          end

          super
        end
      end
    end

    register_plugin(:ignore_assign_current, IgnoreAssignCurrent)
  end
end
