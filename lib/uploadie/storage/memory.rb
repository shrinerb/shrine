require "stringio"

class Uploadie
  module Storage
    class Memory
      def initialize(store = {})
        @store = store
      end

      def upload(io, id)
        @store[id] = io.read
        io.rewind

        url(id)
      end

      def download(id)
        tempfile = Tempfile.new(id, binmode: true)
        tempfile.write(read(id))
        tempfile.rewind
        tempfile.fsync

        tempfile
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
