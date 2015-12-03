require "stringio"
require "down"

class Shrine
  module Storage
    class Memory
      def initialize(store = {})
        @store = store
      end

      def upload(io, id, metadata = {})
        @store[id] = io.read
      end

      def download(id)
        Down.copy_to_tempfile(id, open(id))
      end

      def open(id)
        StringIO.new(@store.fetch(id))
      end

      def read(id)
        @store.fetch(id).dup
      end

      def exists?(id)
        @store.key?(id)
      end

      def delete(id)
        @store.delete(id) or raise "file doesn't exist"
      end

      def url(id, **options)
        "memory://#{id}"
      end

      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm
        @store.clear
      end
    end
  end
end
