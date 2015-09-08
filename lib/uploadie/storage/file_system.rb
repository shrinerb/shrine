require "fileutils"
require "tempfile"
require "find"

class Uploadie
  module Storage
    class FileSystem
      attr_reader :directory, :subdirectory

      def initialize(directory, root: nil)
        if root
          @subdirectory = directory
          @directory = File.join(root, directory)
        else
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
        tempfile = Tempfile.new(id, binmode: true)
        IO.copy_stream(open(id), tempfile)
        tempfile.rewind
        tempfile.fsync

        tempfile
      end

      def open(id)
        ::File.open(path(id), "rb")
      end

      def read(id)
        ::File.read(path(id))
      end

      def exists?(id)
        ::File.exist?(path(id))
      end

      def delete(id)
        FileUtils.rm(path(id))
      end

      def url(id)
        path(id)
      end

      def path(id)
        if subdirectory
          "/" + ::File.join(subdirectory, id)
        else
          ::File.join(directory, id)
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
