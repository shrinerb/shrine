require "stringio"
require "down"

class Shrine
  module Storage
    class Memory
      attr_reader :store

      def initialize(store = {})
        @store = store
      end

      def upload(io, id, metadata = {})
        store[id] = io.read
      end

      def download(id)
        Down.copy_to_tempfile(id, open(id))
      end

      def move(io, id, metadata = {})
        store[id] = store.delete(io.id)
      end

      def movable?(io, id)
        io.is_a?(UploadedFile) &&
        io.storage.is_a?(Storage::Memory) &&
        io.storage.store == store
      end

      def stream(id)
        yield read(id), read(id).length
      end

      def open(id)
        StringIO.new(store.fetch(id))
      end

      def read(id)
        store.fetch(id).dup
      end

      def exists?(id)
        store.key?(id)
      end

      def delete(id)
        store.delete(id) or raise "file doesn't exist"
      end

      def multi_delete(ids)
        ids.each { |id| delete(id) }
      end

      def url(id, **options)
        "memory://#{id}"
      end

      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm
        store.clear
      end
    end
  end
end
