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
    # fails a LintError is raised.
    class Linter
      def self.call(storage)
        new(storage).call
      end

      def initialize(storage)
        @storage = storage
        @errors = []
      end

      def call
        fakeio = FakeIO.new("image")

        storage.upload(fakeio, "foo.jpg", {"mime_type" => "image/jpeg"})
        error! "#upload doesn't rewind the file" if !(fakeio.read == "image")

        file = storage.download("foo.jpg")
        error! "#download doesn't return a Tempfile" if !file.is_a?(Tempfile)
        error! "#download doesn't return the uploaded file" if !(file.read == "image")

        if storage.respond_to?(:move)
          if storage.respond_to?(:movable?)
            error! "#movable? doesn't accept 2 arguments" if !(storage.method(:movable?).arity == 2)
            error! "#move doesn't accept 3 arguments" if !(storage.method(:move).arity == -3)
          else
            error! "doesn't respond to #movable?" if !storage.respond_to?(:movable?)
          end
        end

        if !io?(storage.open("foo.jpg"))
          error! "#open doesn't return a valid IO object"
        end

        error! "#read doesn't return content of the uploaded file" if !(storage.read("foo.jpg") == "image")
        error! "#exists? returns false for a file that was uploaded" if !storage.exists?("foo.jpg")
        error! "#url doesn't return a string" if !storage.url("foo.jpg", {}).is_a?(String)

        storage.delete("foo.jpg")
        error! "#exists? returns true for a file that was deleted" if storage.exists?("foo.jpg")

        begin
          storage.clear!
          error! "#clear! should raise Shrine::Confirm unless :confirm is passed in"
        rescue Shrine::Confirm
        end

        storage.upload(FakeIO.new("image"), "foo.jpg", {"mime_type" => "image/jpeg"})
        storage.clear!(:confirm)
        error! "a file still #exists? after #clear! was called" if storage.exists?("foo.jpg")

        raise LintError.new(@errors) if @errors.any?
      end

      private

      def io?(object)
        missing_methods = IO_METHODS.reject do |m, a|
          object.respond_to?(m) && [a.count, -1].include?(object.method(m).arity)
        end
        missing_methods.empty?
      end

      def error!(message)
        @errors << message
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
