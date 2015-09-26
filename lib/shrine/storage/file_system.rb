require "down"

require "fileutils"
require "pathname"

class Shrine
  module Storage
    class FileSystem
      attr_reader :directory, :subdirectory, :host, :permissions

      def initialize(directory, subdirectory: nil, host: nil, clean: true, permissions: nil)
        if subdirectory
          @subdirectory = Pathname(relative(subdirectory))
          @directory = Pathname(directory).join(@subdirectory)
        else
          @directory = Pathname(directory)
        end

        @host = host
        @permissions = permissions
        @clean = clean

        @directory.mkpath
        @directory.chmod(permissions) if permissions
      end

      def upload(io, id)
        IO.copy_stream(io, path!(id))
        io.rewind
        path(id).chmod(permissions) if permissions
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
        path(id).chmod(permissions) if permissions
      end

      def movable?(io, id)
        io.respond_to?(:path) && !io.path.nil?
      end

      def open(id)
        path(id).open("rb")
      end

      def read(id)
        path(id).binread
      end

      def exists?(id)
        path(id).exist?
      end

      def delete(id)
        path(id).delete
        clean(id) if clean?
      end

      def url(id, **options)
        if subdirectory
          File.join(host || "", subdirectory, id)
        else
          if host
            File.join(host, path(id))
          else
            path(id).to_s
          end
        end
      end

      def clear!(confirm = nil, older_than: nil)
        if older_than
          directory.find do |path|
            path.mtime < older_than ? path.rmtree : Find.prune
          end
        else
          raise Shrine::Confirm unless confirm == :confirm
          directory.rmtree
          directory.mkpath
          directory.chmod(permissions) if permissions
        end
      end

      def path(id)
        directory.join(relative(id))
      end

      def clean(id)
        path(id).dirname.ascend do |pathname|
          if pathname.children.empty? && pathname != directory
            pathname.rmdir
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
        path(id).dirname.mkpath
        path(id)
      end

      def relative(path)
        path.sub(%r{^/}, "")
      end
    end
  end
end
