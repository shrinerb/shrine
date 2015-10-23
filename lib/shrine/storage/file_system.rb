require "down"

require "fileutils"
require "pathname"

class Shrine
  module Storage
    class FileSystem
      attr_reader :directory, :subdirectory, :host, :permissions

      # The `directory` is the root directory where uploaded files will be
      # stored. In web applications this is typically the "public/" directory,
      # to make the files available via URL.
      #
      # If `:subdirectory` is given, #url will return a URL relative to
      # `directory` (and include `:subdirectory`). So, `FileSystem.new('public',
      # subdirectory: 'uploads')` will upload files to "public/uploads", and
      # URLs will be "/uploads/*".
      #
      # In applications it's common to serve files over CDN, so an additional
      # `:host` option can be provided. This option can also be used without
      # `:subdirectory`, if for example files are located on another server
      # which requires an IP address.
      #
      # By default FileSystem will clean empty directories when files get
      # deleted. However, if this puts too much load on the filesystem, it can
      # be disabled with `clean: false`.
      #
      # Optional folder and file permissions can be set through the
      # `:permissions` option.
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

      # Copies the file into the given location.
      def upload(io, id, metadata = {})
        IO.copy_stream(io, path!(id)); io.rewind
        path(id).chmod(permissions) if permissions
      end

      # Downloads the file from the given location, and returns a `Tempfile`.
      def download(id)
        Down.copy_to_tempfile(id, open(id))
      end

      # Moves the file to the given location. This gets called by the "moving"
      # plugin.
      def move(io, id, metadata = {})
        if io.respond_to?(:path)
          FileUtils.mv io.path, path!(id)
        else
          FileUtils.mv io.storage.path(io.id), path!(id)
          io.storage.clean(io.id) if io.storage.clean?
        end
        path(id).chmod(permissions) if permissions
      end

      # Returns true if the file is a `File` or a UploadedFile uploaded by the
      # FileSystem storage.
      def movable?(io, id)
        io.respond_to?(:path) ||
          (io.is_a?(UploadedFile) && io.storage.is_a?(Storage::FileSystem))
      end

      # Opens the file on the given location in read mode.
      def open(id)
        path(id).open("rb")
      end

      # Returns the contents of the file as a String.
      def read(id)
        path(id).binread
      end

      # Returns true if the file exists on the filesystem.
      def exists?(id)
        path(id).exist?
      end

      # Delets the file, and by default deletes the containing directory if
      # it's empty.
      def delete(id)
        path(id).delete
        clean(id) if clean?
      end

      # If #subdirectory is present, returns the path relative to #directory,
      # with an optional #host in front. Otherwise returns the full path to the
      # file (also with an optional #host).
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

      # Without any options it deletes all files from the #directory (and this
      # requires confirmation). If `:older_than` is passed in (a `Time`
      # object), deletes all files which were last modified before that time.
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

      protected

      # Returns the full path to the file.
      def path(id)
        directory.join(relative(id))
      end

      # Cleans all empty subdirectories up the hierarchy.
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

      # Creates all intermediate directories for that location.
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
