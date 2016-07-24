require "aws-sdk"
require "down"
require "uri"

class Shrine
  module Storage
    # The S3 storage handles uploads to Amazon S3 service, it depends on the
    # [aws-sdk] gem:
    #
    #     gem "aws-sdk", "~> 2.1"
    #
    # It is initialized with the following 4 required options:
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
    # ## Upload options
    #
    # Sometimes you'll want to add additional upload options to all S3 uploads.
    # You can do that by passing the `:upload` option:
    #
    #     Shrine::Storage::S3.new(
    #       upload_options: {acl: "public-read", cache_control: "public, max-age=3600"},
    #       **s3_options
    #     )
    #
    # These options will be passed to aws-sdk's methods for [uploading],
    # [copying] and [presigning].
    #
    # You can also generate upload options per upload with the `upload_options`
    # plugin:
    #
    #     class MyUploader < Shrine
    #       plugin :upload_options, store: ->(io, context) do
    #         if context[:version] == :thumb
    #           {acl: "public-read"}
    #         else
    #           {acl: "private"}
    #         end
    #       end
    #     end
    #
    # Note that these aren't applied to presigns, since presigns are generated
    # using the storage directly.
    #
    # ## CDN
    #
    # If you're using a CDN with S3 like Amazon CloudFront, you can specify
    # the `:host` option to have all your URLs use the CDN host:
    #
    #     Shrine::Storage::S3.new(host: "http://abc123.cloudfront.net", **s3_options)
    #
    # ## Clearing cache
    #
    # If you're using S3 as a cache, you will probably want to periodically
    # delete old files which aren't used anymore. S3 has a built-in way to do
    # this, read [this article](http://docs.aws.amazon.com/AmazonS3/latest/UG/lifecycle-configuration-bucket-no-versioning.html)
    # for instructions.
    #
    # [uploading]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#put-instance_method
    # [copying]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#copy_from-instance_method
    # [presigning]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#presigned_post-instance_method
    # [aws-sdk]: https://github.com/aws/aws-sdk-ruby
    class S3
      attr_reader :s3, :bucket, :prefix, :host, :upload_options

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
      # :   This option is used for setting CDNs, e.g. it can be set to
      #      `//abc123.cloudfront.net`.
      #
      # :upload_options
      # :   Additional options that will be used for uploading files, they will
      #     be passed to [`Aws::S3::Object#put`], [`Aws::S3::Object#copy_from`]
      #     and [`Aws::S3::Bucket#presigned_post`].
      #
      # :multipart_threshold
      # :   The file size over which the storage will use parallelized
      #     multipart copy/upload. Default is `15*1024*1024` (15MB).
      #
      # All other options are forwarded to [`Aws::S3::Client#initialize`].
      #
      # [`Aws::S3::Object#put`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#put-instance_method
      # [`Aws::S3::Object#copy_from`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#copy_from-instance_method
      # [`Aws::S3::Bucket#presigned_post`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#presigned_post-instance_method
      # [`Aws::S3::Client#initialize`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html#initialize-instance_method
      def initialize(bucket:, prefix: nil, host: nil, upload_options: {}, multipart_threshold: 15*1024*1024, **s3_options)
        @prefix = prefix
        @s3 = Aws::S3::Resource.new(**s3_options)
        @bucket = @s3.bucket(bucket)
        @host = host
        @upload_options = upload_options
        @multipart_threshold = multipart_threshold
      end

      # If the file is an UploadedFile from S3, issues a COPY command, otherwise
      # uploads the file.
      #
      # It assigns the correct "Content-Type" taken from the MIME type, because
      # by default S3 sets everything to "application/octet-stream".
      def upload(io, id, shrine_metadata: {}, **upload_options)
        options = {content_type: shrine_metadata["mime_type"]}
        options.update(@upload_options)
        options.update(upload_options)

        if copyable?(io)
          copy(io, id, **options)
        else
          put(io, id, **options)
        end
      end

      # Downloads the file from S3, and returns a `Tempfile`.
      def download(id)
        tempfile = Tempfile.new(["s3", File.extname(id)], binmode: true)
        (object = object(id)).get(response_target: tempfile.path)
        tempfile.singleton_class.instance_eval { attr_accessor :content_type }
        tempfile.content_type = object.content_type
        tempfile.tap(&:open)
      end

      # Alias for #download.
      def open(id)
        Down.open(url(id), ssl_ca_cert: Aws.config[:ssl_ca_bundle])
      end

      # Returns the contents of the file as a String.
      def read(id)
        object(id).get.body.string
      end

      # Returns true file exists on S3.
      def exists?(id)
        object(id).exists?
      end

      # Deletes the file from S3.
      def delete(id)
        object(id).delete
      end

      # This is called when multiple files are being deleted at once. Issues a
      # single MULTI DELETE command for each 1000 objects (S3 delete limit).
      def multi_delete(ids)
        objects = ids.take(1000).map { |id| {key: object(id).key} }
        bucket.delete_objects(delete: {objects: objects})

        rest = Array(ids[1000..-1])
        multi_delete(rest) unless rest.empty?
      end

      # Returns the presigned URL to the file.
      #
      # :public
      # :  Creates an unsigned version of the URL (the permissions on the S3
      #    bucket need to be modified to allow public URLs).
      #
      # :download
      # :  If set to `true`, creates a "forced download" link, which means that
      #    the browser will never display the file and always ask the user to
      #    download it.
      #
      # All other options are forwarded to [`Aws::S3::Object#presigned_url`] or
      # [`Aws::S3::Object#public_url`].
      #
      # [`Aws::S3::Object#presigned_url`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#presigned_url-instance_method
      # [`Aws::S3::Object#public_url`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html#public_url-instance_method
      def url(id, download: nil, public: nil, **options)
        options[:response_content_disposition] = "attachment" if download

        if public
          url = object(id).public_url(**options)
        else
          url = object(id).presigned_url(:get, **options)
        end

        if host
          uri = URI.parse(url)
          uri.path = uri.path.match(/^\/#{bucket.name}/).post_match unless uri.host.include?(bucket.name)
          url = URI.join(host, uri.request_uri).to_s
        end

        url
      end

      # Deletes all files from the storage.
      def clear!
        objects = bucket.object_versions(prefix: prefix)
        if objects.respond_to?(:batch_delete!)
          objects.batch_delete!
        else
          objects.delete
        end
      end

      # Returns a signature for direct uploads. Internally it calls
      # [`Aws::S3::Bucket#presigned_post`], and forwards any additional options
      # to it.
      #
      # [`Aws::S3::Bucket#presigned_post`]: http://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Bucket.html#presigned_post-instance_method
      def presign(id, **options)
        options = upload_options.merge(options)
        object(id).presigned_post(options)
      end

      # Catches the deprecated `#stream` method.
      def method_missing(name, *args)
        if name == :stream
          warn "Shrine::Storage::S3#stream is deprecated over calling #each_chunk on S3#open."
          object = object(*args)
          object.get { |chunk| yield chunk, object.content_length }
        else
          super
        end
      end

      protected

      # Returns the S3 object.
      def object(id)
        bucket.object([*prefix, id].join("/"))
      end

      # This is used to check whether an S3 file is copyable.
      def access_key_id
        s3.client.config.credentials.credentials.access_key_id
      end

      private

      # Copies an existing S3 object to a new location.
      def copy(io, id, **options)
        options = {multipart_copy: true, content_length: io.size}.update(options) if multipart?(io)
        object(id).copy_from(io.storage.object(io.id), **options)
      end

      # Uploads the file to S3.
      def put(io, id, **options)
        if io.respond_to?(:path)
          options = {multipart_threshold: @multipart_threshold}.update(options)
          object(id).upload_file(io.path, **options)
        else
          object(id).put(body: io, **options)
        end
      end

      # The file is copyable if it's on S3 and on the same Amazon account.
      def copyable?(io)
        io.is_a?(UploadedFile) &&
        io.storage.is_a?(Storage::S3) &&
        io.storage.access_key_id == access_key_id
      end

      # Determines whether multipart upload/copy should be used from
      # `:multipart_threshold`.
      def multipart?(io)
        io.size && io.size >= @multipart_threshold
      end
    end
  end
end
