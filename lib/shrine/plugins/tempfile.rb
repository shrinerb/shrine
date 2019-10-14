# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/tempfile
    module Tempfile
      module ClassMethods
        def with_file(io)
          if io.is_a?(UploadedFile) && io.opened?
            # open a new file descriptor for thread safety
            File.open(io.tempfile.path, binmode: true) do |file|
              yield file
            end
          else
            super
          end
        end
      end

      module FileMethods
        def tempfile
          raise Error, "uploaded file must be opened" unless @io

          @tempfile ||= download
          @tempfile.rewind
          @tempfile
        end

        def close
          super

          @tempfile.close! if @tempfile
          @tempfile = nil
        end
      end
    end

    register_plugin(:tempfile, Tempfile)
  end
end
