# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/keep_files.md] on GitHub.
    #
    # [doc/plugins/keep_files.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/keep_files.md
    module KeepFiles
      module AttacherMethods
        def destroy_attached(*)
          # don't delete files
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
