require "shrine"

require "forwardable"
require "stringio"
require "tempfile"

class Shrine
  # Error which is thrown when Storage::Linter fails.
  class LintError < Error
  end

  module Storage
    # Checks if the storage conforms to Shrine's specification.
    #
    #   Shrine::Storage::Linter.new(storage).call
    #
    # If the check fails, by default it raises a `Shrine::LintError`, but you
    # can also specify `action: :warn`:
    #
    #   Shrine::Storage::Linter.new(storage, action: :warn).call
    #
    # You can also specify an IO factory which the storage will use:
    #
    #   Shrine::Storage::Linter.new(storage).call(->{File.open("test/fixtures/image.jpg")})
    class Linter
      def self.call(*args)
        new(*args).call
      end

      def initialize(storage, action: :error)
        @storage = storage
        @action  = action
      end

      def call(io_factory = default_io_factory)
        storage.upload(io_factory.call, id = "foo", {})

        lint_download(id)
        lint_open(id)
        lint_exists(id)
        lint_url(id)
        lint_delete(id)

        if storage.respond_to?(:move)
          uploaded_file = uploader.upload(io_factory.call, location: "bar")
          lint_move(uploaded_file, "quux")
        end

        if storage.respond_to?(:multi_delete)
          storage.upload(io_factory.call, id = "baz")
          lint_multi_delete(id)
        end

        storage.upload(io_factory.call, id = "quux")
        lint_clear(id)
      end

      def lint_download(id)
        downloaded = storage.download(id)
        error :download, "doesn't return a Tempfile" if !downloaded.is_a?(Tempfile)
        error :download, "returns an empty IO object" if downloaded.read.empty?
      end

      def lint_open(id)
        opened = storage.open(id)
        error :open, "doesn't return a valid IO object" if !io?(opened)
        error :open, "returns an empty IO object" if opened.read.empty?
        opened.close
      end

      def lint_exists(id)
        error :exists?, "returns false for a file that was uploaded" if !storage.exists?(id)
      end

      def lint_url(id)
        # just assert #url exists, it isn't required to return anything
        url = storage.url(id)
        error :url, "should return either nil or a string" if !(url.nil? || url.is_a?(String))
      end

      def lint_delete(id)
        storage.delete(id)
        error :delete, "file still #exists? after deleting" if storage.exists?(id)
      end

      def lint_move(uploaded_file, id)
        if storage.movable?(uploaded_file, id)
          storage.move(uploaded_file, id, {})
          error :exists?, "returns false for destination after #move" if !storage.exists?(id)
          error :exists?, "returns true for source after #move" if storage.exists?(uploaded_file.id)
        end
      end

      def lint_multi_delete(id)
        storage.multi_delete([id])
        error :exists?, "returns true for a file that was multi-deleted" if storage.exists?(id)
      end

      def lint_clear(id)
        storage.clear!
        error :clear!, "file still #exists? after clearing" if storage.exists?(id)
      end

      private

      attr_reader :storage

      def uploader
        shrine = Class.new(Shrine)
        shrine.storages[:storage] = storage
        shrine.new(:storage)
      end

      def io?(object)
        uploader.send(:_enforce_io, object)
        true
      rescue Shrine::InvalidFile
        false
      end

      def error(method_name, message)
        if @action == :error
          raise LintError, full_message(method_name, message)
        else
          warn full_message(method_name, message)
        end
      end

      def full_message(method_name, message)
        "#{@storage.class}##{method_name} - #{message}"
      end

      def default_io_factory
        -> { FakeIO.new("file") }
      end

      class FakeIO
        def initialize(content)
          @io = StringIO.new(content)
        end

        extend Forwardable
        delegate Shrine::IO_METHODS.keys => :@io
      end
    end
  end
end
