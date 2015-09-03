require "stringio"

class Uploadie
  module Storage
    class Memory
      def initialize(store = {})
        @store = store
      end

      def upload(io, id)
        @store[id] = io.read
        url(id)
      end

      def download(id)
        StringIO.new(read(id))
      end

      def open(id)
        StringIO.new(@store[id])
      end

      def read(id)
        @store[id].dup
      end

      def size(id)
        @store[id].bytesize
      end

      def exists?(id)
        @store.key?(id)
      end

      def delete(id)
        @store.delete(id)
      end

      def url(id)
        "memory://#{id}"
      end

      def clear!(confirm = nil)
        raise Uploadie::Confirm unless confirm == :confirm
        @store.clear
      end
    end
  end
end
