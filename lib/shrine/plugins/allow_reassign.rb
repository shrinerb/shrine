# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/allow_reassign
    module AllowReassign
      module AttacherMethods
        def assign(value, **options)
          super
        rescue Shrine::NotCached
          fail unless uploaded_file(value) == file
        end
      end
    end

    register_plugin(:allow_reassign, AllowReassign)
  end
end
