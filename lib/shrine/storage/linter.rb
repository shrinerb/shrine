# frozen_string_literal: true

require "shrine"

require "forwardable"
require "stringio"
require "tempfile"
require "securerandom"

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
        storage.upload(io_factory.call, id = "foo".dup, {})

        lint_open(id)
        lint_exists(id)
        lint_url(id)
        lint_delete(id)

        if storage.respond_to?(:clear!)
          storage.upload(io_factory.call, id = "quux".dup)
          lint_clear(id)
        end

        if storage.respond_to?(:presign)
          lint_presign(id)
        end
      end

      def lint_open(id)
        opened = storage.open(id, {})
        error :open, "doesn't return a valid IO object" if !io?(opened)
        error :open, "returns an empty IO object" if opened.read.empty?
        opened.close

        begin
          storage.open("nonexisting", {})
          error :open, "should raise an exception on nonexisting file"
        rescue Shrine::FileNotFound
        rescue => exception
          error :open, "should raise Shrine::FileNotFound on nonexisting file"
        end
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
        begin
          storage.delete(id)
        rescue => exception
          error :delete, "shouldn't fail if the file doesn't exist, but raised #{exception.class}"
        end
      end

      def lint_clear(id)
        storage.clear!
        error :clear!, "file still #exists? after clearing" if storage.exists?(id)
      end

      def lint_presign(id)
        data = storage.presign(id, {})
        error :presign, "result should be a Hash" unless data.respond_to?(:to_h)
        error :presign, "result should include :method key" unless data.to_h.key?(:method)
        error :presign, "result should include :url key" unless data.to_h.key?(:url)
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
        delegate %i[read rewind eof? close size] => :@io
      end
    end
  end
end
