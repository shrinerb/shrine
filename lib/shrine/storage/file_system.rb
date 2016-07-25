require "down"

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
    # This storage will upload all files to "public/uploads", and the URLs
    # of the uploaded files will start with "/uploads/*". This way you can
    # use FileSystem for both cache and store, one having the prefix
    # "uploads/cache" and other "uploads/store".
    #
    # You can also initialize the storage just with the "base" directory, and
    # then the FileSystem storage will generate absolute URLs to files:
    #
    #     storage = Shrine::Storage::FileSystem.new(Dir.tmpdir)
    #     storage.url("image.jpg") #=> "/var/folders/k7/6zx6dx6x7ys3rv3srh0nyfj00000gn/T/image.jpg"
    #
    # ## Host
    #
    # It's generally a good idea to serve your files via a CDN, so an
    # additional `:host` option can be provided:
    #
    #     storage = Shrine::Storage::FileSystem.new("public",
    #       prefix: "uploads", host: "http://abc123.cloudfront.net")
    #     storage.url("image.jpg") #=> "http://abc123.cloudfront.net/uploads/image.jpg"
    #
    # If you're not using a CDN, it's recommended that you still set `:host` to
    # your application's domain (at least in production).
    #
    # The `:host` option can also be used wihout `:prefix`, and is
    # useful if you for example have files located on another server:
    #
    #     storage = Shrine::Storage::FileSystem.new("files", host: "http://943.23.43.1")
    #     storage.url("image.jpg") #=> "http://943.23.43.1/files/image.jpg"
    #
    # ## Clearing cache
    #
    # If you're using FileSystem as cache, you will probably want to
    # periodically delete old files which aren't used anymore. You can put
    # the following in a periodic Rake task:
    #
    #     file_system = Shrine.storages[:cache]
    #     file_system.clear!(older_than: 1.week.ago) # adjust the time
    #
    # ## Permissions
    #
    # If you want your files and folders to have certain permissions, you can
    # pass the `:permissions` option:
    #
    #     Shrine::Storage::FileSystem.new("directory", permissions: 0755)
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
    # download_endpoint plugin.
    class FileSystem
      attr_reader :directory, :prefix, :host, :permissions

      # Initializes a storage for uploading to the filesystem.
      #
      # :prefix
      # :  The directory relative to `directory` to which files will be stored,
      #    and it is included in the URL.
      #
      # :host
      # :  URLs will by default be relative if `:prefix` is set, and you
      #    can use this option to set a CDN host (e.g. `//abc123.cloudfront.net`).
      #
      # :permissions
      # :  The generated files and folders will have default UNIX permissions,
      #    but if you want specific ones you can use this option (e.g. `0755`).
      #
      # :clean
      # :  By default empty folders inside the directory are automatically
      #    deleted, but if it happens that it causes too much load on the
      #    filesystem, you can set this option to `false`.
      def initialize(directory, prefix: nil, host: nil, clean: true, permissions: nil)
        if prefix
          @prefix = Pathname(relative(prefix))
          @directory = Pathname(directory).join(@prefix)
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
      def upload(io, id, shrine_metadata: {}, **upload_options)
        IO.copy_stream(io, path!(id))
        path(id).chmod(permissions) if permissions
      end

      # Downloads the file from the given location, and returns a `Tempfile`.
      def download(id)
        open(id) { |file| Down.copy_to_tempfile(id, file) }
      end

      # Moves the file to the given location. This gets called by the "moving"
      # plugin.
      def move(io, id, shrine_metadata: {}, **upload_options)
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
      def open(id, &block)
        path(id).open("rb", &block)
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

      # If #prefix is present, returns the path relative to #directory,
      # with an optional #host in front. Otherwise returns the full path to the
      # file (also with an optional #host).
      def url(id, **options)
        path = (prefix ? relative_path(id) : path(id)).to_s
        host ? host + path : path
      end

      # Deletes all files from the #directory. If `:older_than` is passed in (a
      # `Time` object), deletes all files which were last modified before that
      # time.
      def clear!(older_than: nil)
        if older_than
          directory.find do |path|
            path.mtime < older_than ? path.rmtree : Find.prune
          end
        else
          directory.rmtree
          directory.mkpath
          directory.chmod(permissions) if permissions
        end
      end

      protected

      # Returns the full path to the file.
      def path(id)
        directory.join(id.gsub("/", File::SEPARATOR))
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

      def relative_path(id)
        "/" + prefix.join(id.gsub("/", File::SEPARATOR)).to_s
      end

      def relative(path)
        path.sub(%r{^/}, "")
      end
    end
  end
end
