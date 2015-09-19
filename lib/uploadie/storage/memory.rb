require "stringio"
require "uploadie/utils"

class Uploadie
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
        Uploadie::Utils.copy_to_tempfile(id, open(id))
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
