require "uploadie/utils"

require "fileutils"
require "find"

class Uploadie
  module Storage
    class FileSystem
      attr_reader :directory, :subdirectory, :host

      def initialize(directory, subdirectory: nil, host: nil)
        if subdirectory
          @subdirectory = subdirectory
          @directory = File.join(directory, subdirectory)
        else
          @directory = directory
        end
        @host = host

        FileUtils.mkdir_p(@directory)
      end

      def upload(io, id)
        IO.copy_stream(io, path!(id))
        io.rewind
      end

      def download(id)
        Uploadie::Utils.copy_to_tempfile(id, open(id))
      end

      def open(id)
        File.open(path(id), "rb")
      end

      def read(id)
        File.read(path(id))
      end

      def exists?(id)
        File.exist?(path(id))
      end

      def delete(id)
        FileUtils.rm(path(id))
      end

      def url(id)
        if subdirectory
          File.join(host || "", File.join(subdirectory, id))
        else
          if host
            File.join(host, File.join(directory, id))
          else
            File.join(directory, id)
          end
        end
      end

      def path(id)
        File.join(directory, id)
      end

      def clear!(confirm = nil, older_than: nil)
        if older_than
          Find.find(directory) do |path|
            File.mtime(path) < older_than ? FileUtils.rm_r(path) : Find.prune
          end
        else
          raise Uploadie::Confirm unless confirm == :confirm
          FileUtils.rm_r(directory)
          FileUtils.mkdir_p(directory)
        end
      end

      private

      def path!(id)
        FileUtils.mkdir_p File.dirname(path(id))
        path(id)
      end
    end
  end
end
