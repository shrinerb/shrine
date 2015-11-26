require "aws-sdk"
require "down"
require "uri"

class Shrine
  module Storage
    # The S3 storage handles uploads to Amazon S3 service, and it is
    # initialized with the following 4 required options:
    #
    #     Shrine::Storage::S3.new(
    #       access_key_id: "xyz",
    #       secret_access_key: "abc",
    #       region: "eu-west-1",
    #       bucket: "my-app",
    #     )
    #
    # ## Prefix
    #
    # The `:prefix` option can be specified for uploading all files inside
    # a specific S3 prefix (folder), which is useful when using S3 for both
    # cache and store:
    #
    #     Shrine::Storage::S3.new(prefix: "cache", **s3_options)
    #     Shrine::Storage::S3.new(prefix: "store", **s3_options)
    #
    # ## CDN
    #
    # If you're using a CDN with S3 like Amazon CloudFront, you can specify
    # the `:host` option to have all your URLs use the CDN host and set the
    # `:cache_control` to tell CloudFront how long to cache the file and the
    # `:acl` option to allow CloudFront to read the file from S3.
    #
    #     Shrine::Storage::S3.new(
    #       host: "//abc123.cloudfront.net",
    #       cache_control: "public, max-age=#{30.days}",
    #       acl: "public-read",
    #       **s3_options
    #     )
    #
    # ## Clearing cache
    #
    # If you're using S3 as a cache, you will probably want to periodically
    # delete old files which aren't used anymore. S3 has a built-in way to do
    # this, read [this article](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html)
    # for instructions.
    class S3
      attr_reader :prefix, :bucket, :s3, :host, :cache_control, :acl

      # Initializes a storage for uploading to S3.
      #
      # :access_key_id
      # :secret_access_key
      # :region
      # :bucket
      # :   Credentials required by the `aws-sdk` gem.
      #
      # :prefix
      # :   "Folder" name inside the bucket to store files into.
      #
      # :host
      # :   This option is used for setting CDNs, e.g. it can be set to `//abc123.cloudfront.net`.
      #
      # :cache_control
      # :   This option is used for setting permissions for CloudFront, e.g. it can be set to `public, max-age=#{30.days}`.
      #
      # :acl
      # :   This option is used for setting permissions for CloudFront, e.g. it can be set to `public-read`.
      #
      # All other options are forwarded to [`Aws::S3::Client#initialize`](http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html#initialize-instance_method).
      def initialize(bucket:, prefix: nil, host: nil, cache_control: nil, acl: nil, **s3_options)
        @prefix = prefix
        @s3 = Aws::S3::Resource.new(**s3_options)
        @bucket = @s3.bucket(bucket)
        @host = host
        @cache_control = cache_control
        @acl = acl
      end

      # If the file is an UploadedFile from S3, issues a COPY command, otherwise
      # uploads the file.
      #
      # It assigns the correct "Content-Type" taken from the MIME type, because
      # by default S3 sets everything to "application/octet-stream".
      def upload(io, id, metadata = {})
        options = {
          content_type: metadata["mime_type"],
          cache_control: cache_control,
          acl: acl
        }

        if copyable?(io)
          object(id).copy_from(io.storage.object(io.id), **options)
        else
          object(id).put(body: io, **options)
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
        objects = ids.map { |id| {key: object(id).key} }
        bucket.delete_objects(delete: {objects: objects})
      end

      # Returns the presigned URL to the file.
      #
      # :download
      # :  If set to `true`, creates a "forced download" link, which means that
      #    the browser will never display the file and always ask the user to
      #    download it.
      #
      # :public
      # :  Creates an unsigned version of the URL (requires setting appropriate
      #    permissions on the S3 bucket).
      #
      # options
      # :  All other optione are forwarded to 
      # If `download: true` is passed,
      # returns a forced download link. If `public: true` is passed, it returns
      # an unsigned S3 URL. All other options are forwarded to
      # [`Aws::S3::Object#presigned_url`], so take a look there for the
      # complete list of additional options.
      #
      # [`Aws::S3::Object#presigned_url`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#presigned_url-instance_method
      def url(id, download: nil, public: nil, **options)
        if host.nil?
          options[:response_content_disposition] = "attachment" if download
          if public.nil?
            object(id).presigned_url(:get, **options)
          else
            object(id).public_url(**options)
          end
        else
          URI.join(host, object(id).key).to_s
        end
      end

      # Deletes all files from the storage (requires confirmation).
      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm
        @bucket.object_versions(prefix: prefix).delete
      end

      # Returns a signature for direct uploads. Internally it calls
      # [`Aws::S3::Bucket#presigned_post`], and forwards any additional options
      # to it.
      #
      # [`Aws::S3::Bucket#presigned_post`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Bucket.html#presigned_post-instance_method
      def presign(id, **options)
        @bucket.presigned_post(key: object(id).key, **options)
      end

      protected

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
