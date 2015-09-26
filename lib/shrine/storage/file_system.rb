require "down"

require "fileutils"
require "find"
require "pathname"

class Shrine
  module Storage
    class FileSystem
      attr_reader :directory, :subdirectory, :host, :permissions

      def initialize(directory, subdirectory: nil, host: nil, clean: true, permissions: nil)
        if subdirectory
          @subdirectory = subdirectory
          @directory = File.join(directory, subdirectory)
        else
          @directory = directory
        end

        @host = host
        @permissions = permissions
        @clean = clean

        FileUtils.mkdir_p(@directory, mode: permissions)
      end

      def upload(io, id)
        IO.copy_stream(io, path!(id))
        io.rewind
        FileUtils.chmod(permissions, path(id)) if permissions
      end

      def download(id)
        Down.copy_to_tempfile(id, open(id))
      end

      def move(io, id)
        if io.respond_to?(:path)
          FileUtils.mv io.path, path!(id)
        else
          FileUtils.mv io.storage.path(io.id), path!(id)
          io.storage.clean(io.id) if io.storage.clean?
        end
        FileUtils.chmod(permissions, path(id)) if permissions
      end

      def movable?(io, id)
        io.respond_to?(:path) && !io.path.nil?
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
        clean(id) if clean?
      end

      def url(id, **options)
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

      def clear!(confirm = nil, older_than: nil)
        if older_than
          Find.find(directory) do |path|
            File.mtime(path) < older_than ? FileUtils.rm_r(path) : Find.prune
          end
        else
          raise Shrine::Confirm unless confirm == :confirm
          FileUtils.rm_r(directory)
          FileUtils.mkdir_p(@directory, mode: permissions)
        end
      end

      def path(id)
        File.join(directory, id)
      end

      def clean(id)
        Pathname.new(path(id)).dirname.ascend do |pathname|
          if pathname.children.empty? && pathname.to_s != directory
            FileUtils.rmdir(pathname)
          else
            break
          end
        end
      end

      def clean?
        @clean
      end

      private

      def path!(id)
        FileUtils.mkdir_p File.dirname(path(id))
        path(id)
      end
    end
  end
end
