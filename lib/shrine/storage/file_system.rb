# frozen_string_literal: true

require "fileutils"
require "pathname"

class Shrine
  module Storage
    class FileSystem
      attr_reader :directory, :prefix, :permissions, :directory_permissions

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
      def initialize(directory, prefix: nil, clean: true, permissions: 0644, directory_permissions: 0755)
        if prefix
          @prefix = Pathname(relative(prefix))
          @directory = Pathname(directory).join(@prefix).expand_path
        else
          @directory = Pathname(directory).expand_path
        end

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
        if move && movable?(io)
          move(io, path!(id))
        else
          IO.copy_stream(io, path!(id))
        end

        path(id).chmod(permissions) if permissions
      end

      # Opens the file on the given location in read mode. Accepts additional
      # `File.open` arguments.
      def open(id, **options)
        path(id).open(binmode: true, **options)
      rescue Errno::ENOENT
        raise Shrine::FileNotFound, "file #{id.inspect} not found on storage"
      end

      # Returns true if the file exists on the filesystem.
      def exists?(id)
        path(id).exist?
      end

      # If #prefix is not present, returns a path composed of #directory and
      # the given `id`. If #prefix is present, it excludes the #directory part
      # from the returned path (e.g. #directory can be set to "public" folder).
      # Both cases accept a `:host` value which will be prefixed to the
      # generated path.
      def url(id, host: nil, **options)
        path = (prefix ? relative_path(id) : path(id)).to_s
        host ? host + path : path
      end

      # Delets the file, and by default deletes the containing directory if
      # it's empty.
      def delete(id)
        path = path(id)
        path.delete
        clean(path) if clean?
      rescue Errno::ENOENT
      end

      # Deletes the specified directory on the filesystem.
      #
      #    file_system.delete_prefixed("somekey/derivatives")
      def delete_prefixed(delete_prefix)
        FileUtils.rm_rf directory.join(delete_prefix)
      end

      # Deletes all files from the #directory. If a block is passed in, deletes
      # only the files for which the block evaluates to true.
      #
      #     file_system.clear! # deletes all files and subdirectories in the storage directory
      #     file_system.clear! { |path| path.mtime < Time.now - 7*24*60*60 } # deletes only files older than 1 week
      def clear!(&condition)
        if condition
          list_files(directory) do |path|
            next unless condition.call(path)
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

      protected

      # Cleans all empty subdirectories up the hierarchy.
      def clean(path)
        path.dirname.ascend do |pathname|
          if dir_empty?(pathname) && pathname != directory
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

      # Moves the file to the given location. This gets called by the `moving`
      # plugin.
      def move(io, path)
        if io.respond_to?(:path)
          FileUtils.mv io.path, path
        else
          FileUtils.mv io.storage.path(io.id), path
          io.storage.clean(io.storage.path(io.id)) if io.storage.clean?
        end
      end

      # Returns true if the file is a `File` or a UploadedFile uploaded by the
      # FileSystem storage.
      def movable?(io)
        io.respond_to?(:path) ||
          (io.is_a?(UploadedFile) && io.storage.is_a?(Storage::FileSystem))
      end

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

      if RUBY_VERSION >= "2.4"
        def dir_empty?(path)
          Dir.empty?(path)
        end
      else
        # :nocov:
        def dir_empty?(path)
          Dir.foreach(path) { |x| return false unless [".", ".."].include?(x) }
          true
        end
        # :nocov:
      end
    end
  end
end
