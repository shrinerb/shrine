require "aws-sdk"
require "down"

class Shrine
  module Storage
    class S3
      attr_reader :prefix, :bucket, :s3

      # Example:
      #
      #     Shrine::Storage::S3.new(
      #       access_key_id: "xyz",
      #       secret_access_key: "abc",
      #       region: "eu-west-1"
      #       bucket: "my-app",
      #       prefix: "cache",
      #     )
      #
      # The above storage will store file into the "my-app" bucket in the
      # "cache" directory.
      def initialize(bucket:, prefix: nil, **s3_options)
        @prefix = prefix
        @s3 = Aws::S3::Resource.new(s3_options)
        @bucket = @s3.bucket(bucket)
      end

      # If the file is an UploadedFile from S3, issues a COPY command, otherwise
      # uploads the file.
      #
      # It assigns the correct "Content-Type" taken from the MIME type, because
      # by default S3 sets everything to "application/octet-stream".
      def upload(io, id, metadata = {})
        content_type = metadata["mime_type"]

        if copyable?(io)
          object(id).copy_from(io.storage.object(io.id), content_type: content_type)
        else
          object(id).put(body: io, content_type: content_type)
          io.rewind
        end
      end

      # Downloads the file from S3, and returns a `Tempfile`.
      def download(id)
        Down.download(url(id))
      end

      # Alias for #download.
      def open(id)
        download(id)
      end

      # Returns the contents of the file as a String.
      def read(id)
        object(id).get.body.read
      end

      # Returns true file exists on S3.
      def exists?(id)
        object(id).exists?
      end

      # Deletes the file from S3.
      def delete(id)
        object(id).delete
      end

      # This is called when multiple files are being deleted at once. Issues
      # a single MULTI DELETE command.
      def multi_delete(ids)
        bucket.delete_objects(delete: {objects: ids.map { |id| {key: id} }})
      end

      # Returns the presigned URL to the file. If `download: true` is passed,
      # returns a forced download link.
      def url(id, download: nil, **options)
        options[:response_content_disposition] = "attachment" if download
        object(id).presigned_url(:get, **options)
      end

      # Deletes all files from the storage (requires confirmation).
      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm
        @bucket.clear!
      end

      # Returns the S3 object.
      def object(id)
        @bucket.object([*prefix, id].join("/"))
      end

      # This is used to check whether an S3 file is copyable.
      def access_key_id
        @s3.client.config.credentials.access_key_id
      end

      private

      # The file is copyable if it's on S3 and on the same Amazon account.
      def copyable?(io)
        io.respond_to?(:storage) &&
        io.storage.is_a?(Storage::S3) &&
        io.storage.access_key_id == access_key_id
      end
    end
  end
end
