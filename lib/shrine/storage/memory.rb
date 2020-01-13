# frozen_string_literal: true

require "shrine"
require "stringio"

class Shrine
  module Storage
    class Memory
      attr_reader :store

      def initialize(store = {})
        @store = store
      end

      def upload(io, id, *)
        store[id] = io.read
      end

      def open(id, *)
        str = store.fetch(id)
        # work around apparent bug in ruby 2.7.0
        # https://bugs.ruby-lang.org/issues/16497
        StringIO.new(str).set_encoding(str.encoding)
      rescue KeyError
        raise Shrine::FileNotFound, "file #{id.inspect} not found on storage"
      end

      def exists?(id)
        store.key?(id)
      end

      def url(id, *)
        "memory://#{id}"
      end

      def delete(id)
        store.delete(id)
      end

      def delete_prefixed(delete_prefix)
        delete_prefix = delete_prefix.chomp("/") + "/"
        store.delete_if { |key, _value| key.start_with?(delete_prefix) }
      end

      def clear!
        store.clear
      end
    end
  end
end
