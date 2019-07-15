# frozen_string_literal: true

require "fileutils"
require "pathname"

class Shrine
  module Storage
    class FileSystem
      attr_reader :directory, :prefix, :host, :permissions, :directory_permissions

      # Initializes a storage for uploading to the filesystem.
      #
      # :prefix
      # :  The directory relative to `directory` to which files will be stored,
      #    and it is included in the URL.
      #
      # :permissions
      # :  The UNIX permissions applied to created files. Can be set to `nil`,
      #    in which case the default permissions will be applied. Defaults to
      #    `0644`.
      #
      # :directory_permissions
      # :  The UNIX permissions applied to created directories. Can be set to
      #    `nil`, in which case the default permissions will be applied. Defaults
      #    to `0755`.
      #
      # :clean
      # :  By default empty folders inside the directory are automatically
      #    deleted, but if it happens that it causes too much load on the
      #    filesystem, you can set this option to `false`.
      def initialize(directory, prefix: nil, host: nil, clean: true, permissions: 0644, directory_permissions: 0755)
        Shrine.deprecation("The :host option to Shrine::Storage::FileSystem#initialize is deprecated and will be removed in Shrine 3. Pass :host to FileSystem#url instead, you can also use default_url_options plugin.") if host

        if prefix
          @prefix = Pathname(relative(prefix))
          @directory = Pathname(directory).join(@prefix).expand_path
        else
          @directory = Pathname(directory).expand_path
        end

        @host = host
        @permissions = permissions
        @directory_permissions = directory_permissions
        @clean = clean

        unless @directory.exist?
          @directory.mkpath
          @directory.chmod(directory_permissions) if directory_permissions
        end
      end

      # Copies the file into the given location.
      def upload(io, id, move: false, **)
        if move && movable?(io, id)
          move(io, id)
        else
          IO.copy_stream(io, path!(id))

          path(id).chmod(permissions) if permissions
        end
      end

      # Moves the file to the given location. This gets called by the `moving`
      # plugin.
      def move(io, id, **)
        if io.respond_to?(:path)
          FileUtils.mv io.path, path!(id)
        else
          FileUtils.mv io.storage.path(io.id), path!(id)
          io.storage.clean(io.storage.path(io.id)) if io.storage.clean?
        end

        path(id).chmod(permissions) if permissions
      end

      # Returns true if the file is a `File` or a UploadedFile uploaded by the
      # FileSystem storage.
      def movable?(io, id)
        io.respond_to?(:path) ||
          (io.is_a?(UploadedFile) && io.storage.is_a?(Storage::FileSystem))
      end

      # Opens the file on the given location in read mode. Accepts additional
      # `File.open` arguments.
      def open(id, **options, &block)
        path(id).open(binmode: true, **options, &block)
      end

      # Returns true if the file exists on the filesystem.
      def exists?(id)
        path(id).exist?
      end

      # Delets the file, and by default deletes the containing directory if
      # it's empty.
      def delete(id)
        path = path(id)
        path.delete
        clean(path) if clean?
      rescue Errno::ENOENT
      end

      # If #prefix is not present, returns a path composed of #directory and
      # the given `id`. If #prefix is present, it excludes the #directory part
      # from the returned path (e.g. #directory can be set to "public" folder).
      # Both cases accept a `:host` value which will be prefixed to the
      # generated path.
      def url(id, host: self.host, **options)
        path = (prefix ? relative_path(id) : path(id)).to_s
        host ? host + path : path
      end

      # Deletes all files from the #directory. If a block is passed in, deletes
      # only the files for which the block evaluates to true.
      #
      #     file_system.clear! # deletes all files and subdirectories in the storage directory
      #     file_system.clear! { |path| path.mtime < Time.now - 7*24*60*60 } # deletes only files older than 1 week
      def clear!(older_than: nil, &condition)
        if older_than || condition
          list_files(directory) do |path|
            if older_than
              Shrine.deprecation("The :older_than option to FileSystem#clear! is deprecated and will be removed in Shrine 3. You should use a block instead, e.g. `storage.clear! { |path| path.mtime < Time.now - 7*24*60*60 }`.")
              next unless path.mtime < older_than
            else
              next unless condition.call(path)
            end
            path.delete
            clean(path) if clean?
          end
        else
          directory.children.each(&:rmtree)
        end
      end

      # Returns the full path to the file.
      def path(id)
        directory.join(id.gsub("/", File::SEPARATOR))
      end

      # Catches the deprecated `#download` method.
      def method_missing(name, *args, &block)
        case name
        when :download then deprecated_download(*args, &block)
        else
          super
        end
      end

      protected

      # Cleans all empty subdirectories up the hierarchy.
      def clean(path)
        path.dirname.ascend do |pathname|
          if Dir.empty?(pathname) && pathname != directory
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
        path = path(id)
        FileUtils.mkdir_p(path.dirname, mode: directory_permissions)
        path
      end

      def relative_path(id)
        "/" + prefix.join(id.gsub("/", File::SEPARATOR)).to_s
      end

      def relative(path)
        path.sub(%r{^/}, "")
      end

      def list_files(directory)
        Pathname("#{directory}/") # add trailing slash to make it work with symlinks
          .find
          .each { |path| yield path if path.file? }
      end

      def deprecated_download(id, **options)
        Shrine.deprecation("Shrine::Storage::FileSystem#download is deprecated and will be removed in Shrine 3.")
        tempfile = Tempfile.new(["shrine-filesystem", File.extname(id)], binmode: true)
        open(id, **options) { |file| IO.copy_stream(file, tempfile) }
        tempfile.tap(&:open)
      rescue
        tempfile.close! if tempfile
        raise
      end
    end
  end
end
