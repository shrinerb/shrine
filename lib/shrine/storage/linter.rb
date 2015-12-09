require "shrine"

require "forwardable"
require "stringio"
require "tempfile"

class Shrine
  # Error which is thrown when Storage::Linter fails.
  class LintError < Error
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.to_s)
    end
  end

  module Storage
    # Checks if the storage conforms to Shrine's specification. If the check
    # fails, by default it raises a LintError, but you can also specify
    # `action: :warn`.
    class Linter
      def self.call(*args)
        new(*args).call
      end

      def initialize(storage, action: :error)
        @storage = storage
        @action  = action
        @errors  = []
      end

      def call(io_factory = ->{FakeIO.new("image")})
        storage.upload(io_factory.call, "foo.jpg", {"mime_type" => "image/jpeg"})

        file = storage.download("foo.jpg")
        error! "#download doesn't return a Tempfile" if !file.is_a?(Tempfile)
        error! "#download returns an empty file" if file.read.empty?

        error! "#open doesn't return a valid IO object" if !io?(storage.open("foo.jpg"))
        error! "#read returns an empty string" if storage.read("foo.jpg").empty?
        error! "#exists? returns false for a file that was uploaded" if !storage.exists?("foo.jpg")
        error! "#url doesn't return a string" if !storage.url("foo.jpg", {}).is_a?(String)

        if storage.respond_to?(:move)
          if storage.respond_to?(:movable?)
            error! "#movable? doesn't accept 2 arguments" if !(storage.method(:movable?).arity == 2)
            error! "#move doesn't accept 3 arguments" if !(storage.method(:move).arity == -3)

            uploaded_file = uploader.upload(io_factory.call, location: "bar.jpg")

            if storage.movable?(uploaded_file, "quux.jpg")
              storage.move(uploaded_file, "quux.jpg")
              error! "#exists? returns false for destination after #move" if !storage.exists?("quux.jpg")
              error! "#exists? returns true for source after #move" if storage.exists?("bar.jpg")
            end
          else
            error! "responds to #move but doesn't respond to #movable?" if !storage.respond_to?(:movable?)
          end
        end

        storage.delete("foo.jpg")
        error! "#exists? returns true for a file that was deleted" if storage.exists?("foo.jpg")

        if storage.respond_to?(:multi_delete)
          storage.upload(io_factory.call, "foo.jpg")
          storage.multi_delete(["foo.jpg"])

          error! "#exists? returns true for a file that was multi-deleted" if storage.exists?("foo.jpg")
        end

        begin
          storage.clear!
          error! "#clear! should raise Shrine::Confirm unless :confirm is passed in"
        rescue Shrine::Confirm
        end

        storage.upload(io_factory.call, "foo.jpg", {"mime_type" => "image/jpeg"})
        storage.clear!(:confirm)
        error! "file still #exists? after #clear! was called" if storage.exists?("foo.jpg")

        raise LintError.new(@errors) if @errors.any? && @action == :error
      end

      private

      def uploader
        shrine = Class.new(Shrine)
        shrine.storages[:storage] = storage
        shrine.new(:storage)
      end

      def io?(object)
        missing_methods = IO_METHODS.reject do |m, a|
          object.respond_to?(m) && [a.count, -1].include?(object.method(m).arity)
        end
        missing_methods.empty?
      end

      def error!(message)
        @errors << message
        warn(message) if @action.to_s.start_with?("warn")
      end

      attr_reader :storage

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
