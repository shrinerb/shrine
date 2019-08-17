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
        StringIO.new(store.fetch(id))
      rescue KeyError
        raise Shrine::FileNotFound, "file #{id.inspect} not found on storage"
      end

      def exists?(id)
        store.key?(id)
      end

      def delete(id)
        store.delete(id)
      end

      def url(id, *)
        "memory://#{id}"
      end

      def clear!
        store.clear
      end
    end
  end
end
