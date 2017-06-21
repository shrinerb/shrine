require "shrine/storage/memory"
require "tempfile"

class Shrine
  module Storage
    class Test < Memory
      def download(id)
        tempfile = Tempfile.new("shrine", binmode: true)
        IO.copy_stream(open(id), tempfile)
        tempfile.tap(&:open)
      end

      def move(io, id, **options)
        store[id] = io.storage.delete(io.id)
      end

      def movable?(io, id)
        io.is_a?(UploadedFile) && io.storage.is_a?(Storage::Memory)
      end

      def multi_delete(ids)
        ids.each { |id| delete(id) }
      end
    end
  end
end
