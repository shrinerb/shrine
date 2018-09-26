# frozen_string_literal: true

require "fileutils"
require "pathname"

class Shrine
  module Storage
    # The FileSystem storage handles uploads to the filesystem, and it is
    # most commonly initialized with a "base" folder and a "prefix":
    #
    #     storage = Shrine::Storage::FileSystem.new("public", prefix: "uploads")
    #     storage.url("image.jpg") #=> "/uploads/image.jpg"
    #
    # This storage will upload all files to "public/uploads", and the URLs of
    # the uploaded files will start with "/uploads/*". This way you can use
    # FileSystem for both cache and store, one having the prefix
    # "uploads/cache" and other "uploads/store". If you're uploading files
    # to the `public` directory itself, you need to set `:prefix` to `"/"`:
    #
    #     storage = Shrine::Storage::FileSystem.new("public", prefix: "/") # no prefix
    #     storage.url("image.jpg") #=> "/image.jpg"
    #
    # You can also initialize the storage just with the "base" directory, and
    # then the FileSystem storage will generate absolute URLs to files:
    #
    #     storage = Shrine::Storage::FileSystem.new(Dir.tmpdir)
    #     storage.url("image.jpg") #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/image.jpg"
    #
    # In general you can always retrieve path to the file using `#path`:
    #
    #     storage.path("image.jpg") #=> #<Pathname:public/image.jpg>
    #
    # ## Host
    #
    # It's generally a good idea to serve your files via a CDN, so an
    # additional `:host` option can be provided to `#url`:
    #
    #     storage = Shrine::Storage::FileSystem.new("public", prefix: "uploads")
    #     storage.url("image.jpg", host: "http://abc123.cloudfront.net")
    #     #=> "http://abc123.cloudfront.net/uploads/image.jpg"
    #
    # If you're not using a CDN, it's recommended that you still set `:host` to
    # your application's domain (at least in production).
    #
    # The `:host` option can also be used wihout `:prefix`, and is
    # useful if you for example have files located on another server:
    #
    #     storage = Shrine::Storage::FileSystem.new("/opt/files")
    #     storage.url("image.jpg", host: "http://943.23.43.1")
    #     #=> "http://943.23.43.1/opt/files/image.jpg"
    #
    # ## Clearing cache
    #
    # If you're using FileSystem as cache, you will probably want to
    # periodically delete old files which aren't used anymore. You can run
    # something like this periodically:
    #
    #     file_system = Shrine.storages[:cache]
    #     file_system.clear!(older_than: Time.now - 7*24*60*60) # delete files older than 1 week
    #
    # ## Permissions
    #
    # The storage sets the default UNIX permissions to 0644 for files and 0755
    # for directories, but you can change that:
    #
    #     Shrine::Storage::FileSystem.new("directory", permissions: 0644)
    #     Shrine::Storage::FileSystem.new("directory", directory_permissions: 0755)
    #
    # ## Heroku
    #
    # Note that Heroku has a read-only filesystem, and doesn't allow you to
    # upload your files to the "public" directory, you can however upload to
    # "tmp" directory:
    #
    #     Shrine::Storage::FileSystem.new("tmp/uploads")
    #
    # Note that this approach has a couple of downsides. For example, you can
    # only use it for cache, since Heroku wipes this directory between app
    # restarts. This also means that deploying the app can cancel someone's
    # uploading if you're using backgrounding. Also, by default you cannot
    # generate URLs to files in the "tmp" directory, but you can with the
    # `download_endpoint` plugin.
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
      def upload(io, id, shrine_metadata: {}, **upload_options)
        bytes_copied = IO.copy_stream(io, path!(id))
        path(id).chmod(permissions) if permissions

        shrine_metadata["size"] ||= bytes_copied
      end

      # Moves the file to the given location. This gets called by the `moving`
      # plugin.
      def move(io, id, shrine_metadata: {}, **upload_options)
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
      def open(id, *args, &block)
        path(id).open("rb", *args, &block)
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

      # Deletes all files from the #directory. If `:older_than` is passed in (a
      # `Time` object), deletes all files which were last modified before that
      # time.
      def clear!(older_than: nil)
        if older_than
          directory.find do |path|
            if path.file? && path.mtime < older_than
              path.delete
              clean(path) if clean?
            end
          end
        else
          directory.rmtree
          directory.mkpath
          directory.chmod(directory_permissions) if directory_permissions
        end
      end

      # Returns the full path to the file.
      def path(id)
        directory.join(id.gsub("/", File::SEPARATOR))
      end

      # Catches the deprecated `#download` method.
      def method_missing(name, *args)
        if name == :download
          begin
            Shrine.deprecation("Shrine::Storage::FileSystem#download is deprecated and will be removed in Shrine 3.")
            tempfile = Tempfile.new(["shrine-filesystem", File.extname(args[0])], binmode: true)
            open(*args) { |file| IO.copy_stream(file, tempfile) }
            tempfile.tap(&:open)
          rescue
            tempfile.close! if tempfile
            raise
          end
        else
          super
        end
      end

      protected

      # Cleans all empty subdirectories up the hierarchy.
      def clean(path)
        path.dirname.ascend do |pathname|
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
    end
  end
end
