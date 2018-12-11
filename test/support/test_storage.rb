require "shrine/storage/memory"

class Shrine
  module Storage
    class Test < Memory
      def move(io, id, **options)
        store[id] = io.storage.delete(io.id)
      end

      def movable?(io, id)
        io.is_a?(UploadedFile) && io.storage.is_a?(Storage::Memory)
      end
    end
  end
end
