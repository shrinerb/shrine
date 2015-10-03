require "aws-sdk"
require "down"

class Shrine
  module Storage
    class S3
      attr_reader :directory, :bucket, :s3

      def initialize(bucket:, directory: nil, **s3_options)
        @directory = directory
        @s3 = Aws::S3::Resource.new(s3_options)
        @bucket = @s3.bucket(bucket)
      end

      def upload(io, id, metadata = {})
        if copyable?(io)
          source_location = [io.storage.bucket.name, io.storage.object(io.id).key].join("/")
          object(id).copy_from(copy_source: source_location, content_type: metadata["mime_type"])
        else
          object(id).put(body: io, content_type: metadata["mime_type"])
          io.rewind
        end
      end

      def download(id)
        Down.download(url(id))
      end

      def open(id)
        download(id)
      end

      def read(id)
        object(id).get.body.read
      end

      def exists?(id)
        object(id).exists?
      end

      def delete(id)
        object(id).delete
      end

      def multi_delete(ids)
        bucket.delete_objects(delete: {objects: ids.map { |id| {key: id} }})
      end

      def url(id, **options)
        options[:response_content_disposition] = "attachment" if options.delete(:download)
        object(id).presigned_url(:get, **options)
      end

      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm
        @bucket.clear!
      end

      def object(id)
        @bucket.object([*@directory, id].join("/"))
      end

      def access_key_id
        @s3.client.config.credentials.access_key_id
      end

      private

      def copyable?(io)
        io.respond_to?(:storage) &&
        io.storage.is_a?(S3) &&
        io.storage.access_key_id == access_key_id
      end
    end
  end
end
