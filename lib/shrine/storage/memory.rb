require "stringio"
require "shrine/utils"

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
        Shrine::Utils.copy_to_tempfile(id, open(id))
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
        raise Shrine::Confirm unless confirm == :confirm
        @store.clear
      end
    end
  end
end
