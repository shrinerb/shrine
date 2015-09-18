require "uploadie/utils"

require "fileutils"
require "find"

class Uploadie
  module Storage
    class FileSystem
      attr_reader :directory, :subdirectory, :host

      def initialize(directory, root: nil, host: "")
        if root
          @subdirectory = directory
          @directory = File.join(root, directory)
          @host = host
        else
          raise Error, ":host only works in combination with :root" if !host.empty?
          @directory = directory
        end

        FileUtils.mkdir_p(directory)
      end

      def upload(io, id)
        IO.copy_stream(io, path(id))
        io.rewind

        url(id)
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
        path(id)
      end

      def path(id)
        if subdirectory
          File.join(host, File.join(subdirectory, id))
        else
          File.join(directory, id)
        end
      end

      def clear!(confirm = nil, &condition)
        if condition
          Find.find(directory) do |path|
            condition.(path) ? FileUtils.rm(path) : Find.prune
          end
        else
          raise Uploadie::Confirm unless confirm == :confirm
          FileUtils.rm_rf(directory)
          FileUtils.mkdir_p(directory)
        end
      end
    end
  end
end
