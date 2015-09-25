require "stringio"
require "down"

class Shrine
  module Storage
    class Memory
      def initialize(store = {})
        @store = store
      end

      def upload(io, id)
        @store[id] = io.read
        io.rewind
      end

      def download(id)
        Down.copy_to_tempfile(id, open(id))
      end

      def open(id)
        StringIO.new(@store[id])
      end

      def read(id)
        @store[id].dup
      end

      def exists?(id)
        @store.key?(id)
      end

      def delete(id)
        @store.delete(id)
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
