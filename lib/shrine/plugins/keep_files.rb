# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/keep_files.md] on GitHub.
    #
    # [doc/plugins/keep_files.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/keep_files.md
    module KeepFiles
      def self.configure(uploader, opts = {})
        keep_files = (uploader.opts[:keep_files] ||= [])
        opts[:destroyed] ? keep_files << :destroyed : keep_files.delete(:destroyed) if opts.key?(:destroyed)
        opts[:replaced] ? keep_files << :replaced : keep_files.delete(:replaced) if opts.key?(:replaced)
      end

      module AttacherMethods
        def replace
          super unless shrine_class.opts[:keep_files].include?(:replaced)
        end

        def destroy
          super unless shrine_class.opts[:keep_files].include?(:destroyed)
        end
      end
    end

    register_plugin(:keep_files, KeepFiles)
  end
end
