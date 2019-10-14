# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/keep_files
    module KeepFiles
      module AttacherMethods
        def destroy?
          false
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
