# frozen_string_literal: true

gem "aws-sdk-s3", "~> 1.14"

require "shrine"
require "aws-sdk-s3"

require "down/chunked_io"
require "content_disposition"

require "uri"
require "tempfile"

class Shrine
  module Storage
    class S3
      attr_reader :client, :bucket, :prefix, :upload_options, :signer, :public

      MAX_MULTIPART_PARTS = 10_000
      MIN_PART_SIZE       = 5*1024*1024

      MULTIPART_THRESHOLD = { upload: 15*1024*1024, copy: 100*1024*1024 }

      # Initializes a storage for uploading to S3. All options are forwarded to
      # [`Aws::S3::Client#initialize`], except the following:
      #
      # :bucket
      # : (Required). Name of the S3 bucket.
      #
      # :client
      # : By default an `Aws::S3::Client` instance is created internally from
      #   additional options, but you can use this option to provide your own
      #   client. This can be an `Aws::S3::Client` or an
      #   `Aws::S3::Encryption::Client` object.
      #
      # :prefix
      # : "Directory" inside the bucket to store files into.
      #
      # :upload_options
      # : Additional options that will be used for uploading files, they will
      #   be passed to [`Aws::S3::Object#put`], [`Aws::S3::Object#copy_from`]
      #   and [`Aws::S3::Bucket#presigned_post`].
      #
      # :multipart_threshold
      # : If the input file is larger than the specified size, a parallelized
      #   multipart will be used for the upload/copy. Defaults to
      #   `{upload: 15*1024*1024, copy: 100*1024*1024}` (15MB for upload
      #   requests, 100MB for copy requests).
      #
      # :max_multipart_parts
      # : Limits the number of parts if parellized multipart upload/copy is used.
      # Defaults to 10_000.
      #
      # In addition to specifying the `:bucket`, you'll also need to provide
      # AWS credentials. The most common way is to provide them directly via
      # `:access_key_id`, `:secret_access_key`, and `:region` options. But you
      # can also use any other way of authentication specified in the [AWS SDK
      # documentation][configuring AWS SDK].
      #
      # [`Aws::S3::Object#put`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#put-instance_method
      # [`Aws::S3::Object#copy_from`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#copy_from-instance_method
      # [`Aws::S3::Bucket#presigned_post`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_post-instance_method
      # [`Aws::S3::Client#initialize`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#initialize-instance_method
      # [configuring AWS SDK]: https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-config.html
      def initialize(bucket:, client: nil, prefix: nil, upload_options: {}, multipart_threshold: {}, max_multipart_parts: nil, signer: nil, public: nil, **s3_options)
        raise ArgumentError, "the :bucket option is nil" unless bucket

        @client = client || Aws::S3::Client.new(**s3_options)
        @bucket = Aws::S3::Bucket.new(name: bucket, client: @client)
        @prefix = prefix
        @upload_options = upload_options
        @multipart_threshold = MULTIPART_THRESHOLD.merge(multipart_threshold)
        @max_multipart_parts = max_multipart_parts || MAX_MULTIPART_PARTS
        @signer = signer
        @public = public
      end

      # If the file is an UploadedFile from S3, issues a COPY command, otherwise
      # uploads the file. For files larger than `:multipart_threshold` a
      # multipart upload/copy will be used for better performance and more
      # resilient uploads.
      #
      # It assigns the correct "Content-Type" taken from the MIME type, because
      # by default S3 sets everything to "application/octet-stream".
      def upload(io, id, shrine_metadata: {}, **upload_options)
        content_type, filename = shrine_metadata.values_at("mime_type", "filename")

        options = {}
        options[:content_type] = content_type if content_type
        options[:content_disposition] = ContentDisposition.inline(filename) if filename
        options[:acl] = "public-read" if public

        options.merge!(@upload_options)
        options.merge!(upload_options)

        if copyable?(io)
          copy(io, id, **options)
        else
          put(io, id, **options)
        end
      end

      # Returns a `Down::ChunkedIO` object that downloads S3 object content
      # on-demand. By default, read content will be cached onto disk so that
      # it can be rewinded, but if you don't need that you can pass
      # `rewindable: false`. A required character encoding can be passed in
      # `encoding`; the default is `Encoding::BINARY` via `Down::ChunkedIO`.
      #
      # Any additional options are forwarded to [`Aws::S3::Object#get`].
      #
      # [`Aws::S3::Object#get`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#get-instance_method
      def open(id, rewindable: true, encoding: nil, **options)
        chunks, length = get(id, **options)

        Down::ChunkedIO.new(chunks: chunks, rewindable: rewindable, size: length, encoding: encoding)
      rescue Aws::S3::Errors::NoSuchKey
        raise Shrine::FileNotFound, "file #{id.inspect} not found on storage"
      end

      # Returns true file exists on S3.
      def exists?(id)
        object(id).exists?
      end

      # Returns the presigned URL to the file.
      #
      # :host
      # :  This option replaces the host part of the returned URL, and is
      #    typically useful for setting CDN hosts (e.g.
      #    `http://abc123.cloudfront.net`)
      #
      # :public
      # :  Returns the unsigned URL to the S3 object. This requires the S3
      #    object to be public.
      #
      # All other options are forwarded to [`Aws::S3::Object#presigned_url`] or
      # [`Aws::S3::Object#public_url`].
      #
      # [`Aws::S3::Object#presigned_url`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method
      # [`Aws::S3::Object#public_url`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#public_url-instance_method
      def url(id, public: self.public, host: nil, **options)
        if public || signer
          url = object(id).public_url(**options)
        else
          url = object(id).presigned_url(:get, **options)
        end

        if host
          uri = URI.parse(url)
          uri.path = uri.path.match(/^\/#{bucket.name}/).post_match unless uri.host.include?(bucket.name)
          url = URI.join(host, uri.request_uri[1..-1]).to_s
        end

        if signer
          url = signer.call(url, **options)
        end

        url
      end

      # Returns URL, params, headers, and verb for direct uploads.
      #
      #     s3.presign("key") #=>
      #     # {
      #     #   url: "https://my-bucket.s3.amazonaws.com/...",
      #     #   fields: { ... },  # blank for PUT presigns
      #     #   headers: { ... }, # blank for POST presigns
      #     #   method: "post",
      #     # }
      #
      # By default it calls [`Aws::S3::Object#presigned_post`] which generates
      # data for a POST request, but you can also specify `method: :put` for
      # PUT uploads which calls [`Aws::S3::Object#presigned_url`].
      #
      #     s3.presign("key", method: :post) # for POST upload (default)
      #     s3.presign("key", method: :put)  # for PUT upload
      #
      # Any additional options are forwarded to the underlying AWS SDK method.
      #
      # [`Aws::S3::Object#presigned_post`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_post-instance_method
      # [`Aws::S3::Object#presigned_url`]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method
      def presign(id, method: :post, **presign_options)
        options = {}
        options[:acl] = "public-read" if public

        options.merge!(@upload_options)
        options.merge!(presign_options)

        send(:"presign_#{method}", id, options)
      end

      # Deletes the file from the storage.
      def delete(id)
        object(id).delete
      end

      # Deletes objects at keys starting with the specified prefix.
      #
      #    s3.delete_prefixed("somekey/derivatives/")
      def delete_prefixed(delete_prefix)
        # We need to make sure to combine with storage prefix, and
        # that it ends in '/' cause S3 can be squirrely about matching interior.
        delete_prefix = delete_prefix.chomp("/") + "/"
        bucket.objects(prefix: [*prefix, delete_prefix].join("/")).batch_delete!
      end

      # If block is given, deletes all objects from the storage for which the
      # block evaluates to true. Otherwise deletes all objects from the storage.
      #
      #     s3.clear!
      #     # or
      #     s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 }
      def clear!(&block)
        objects_to_delete = bucket.objects(prefix: prefix)
        objects_to_delete = objects_to_delete.lazy.select(&block) if block

        delete_objects(objects_to_delete)
      end

      # Returns an `Aws::S3::Object` for the given id.
      def object(id)
        bucket.object(object_key(id))
      end

      private

      # Uploads the file to S3. Uses multipart upload for large files.
      def put(io, id, **options)
        if io.respond_to?(:size) && io.size && io.size <= @multipart_threshold[:upload]
          object(id).put(body: io, **options)
        else # multipart upload
          object(id).upload_stream(part_size: part_size(io), **options) do |write_stream|
            IO.copy_stream(io, write_stream)
          end
        end
      end

      # Copies an existing S3 object to a new location. Uses multipart copy for
      # large files.
      def copy(io, id, **copy_options)
        # don't inherit source object metadata or AWS tags
        options = {
          metadata_directive: "REPLACE",
          tagging_directive: "REPLACE"
        }

        if io.size && io.size >= @multipart_threshold[:copy]
          # pass :content_length on multipart copy to avoid an additional HEAD request
          options.merge!(multipart_copy: true, content_length: io.size)
        end

        options.merge!(copy_options)

        object(id).copy_from(io.storage.object(io.id), **options)
      end

      # Generates parameters for a POST upload request.
      def presign_post(id, options)
        presigned_post = object(id).presigned_post(options)

        { method: :post, url: presigned_post.url, fields: presigned_post.fields }
      end

      # Generates parameters for a PUT upload request.
      def presign_put(id, options)
        url = object(id).presigned_url(:put, options)

        # When any of these options are specified, the corresponding request
        # headers must be included in the upload request.
        headers = {}
        headers["Content-Length"]      = options[:content_length]      if options[:content_length]
        headers["Content-Type"]        = options[:content_type]        if options[:content_type]
        headers["Content-Disposition"] = options[:content_disposition] if options[:content_disposition]
        headers["Content-Encoding"]    = options[:content_encoding]    if options[:content_encoding]
        headers["Content-Language"]    = options[:content_language]    if options[:content_language]
        headers["Content-MD5"]         = options[:content_md5]         if options[:content_md5]

        { method: :put, url: url, headers: headers }
      end

      # Determins the part size that should be used when uploading the given IO
      # object via multipart upload.
      def part_size(io)
        return unless io.respond_to?(:size) && io.size

        if io.size <= MIN_PART_SIZE * @max_multipart_parts # <= 50 GB
          MIN_PART_SIZE
        else # > 50 GB
          (io.size.to_f / @max_multipart_parts).ceil
        end
      end

      # Aws::S3::Object#get doesn't allow us to get the content length of the
      # object before all content is downloaded, so we hack our way around it.
      # This way get the content length without an additional HEAD request.
      if Gem::Version.new(Aws::CORE_GEM_VERSION) >= Gem::Version.new("3.104.0")
        def get(id, **params)
          enum = object(id).enum_for(:get, **params)

          begin
            content_length = Integer(enum.peek.last["content-length"])
          rescue StopIteration
            content_length = 0
          end

          chunks = Enumerator.new { |y| loop { y << enum.next.first } }

          [chunks, content_length]
        end
      else
        def get(id, **params)
          req = client.build_request(:get_object, bucket: bucket.name, key: object_key(id), **params)

          body = req.enum_for(:send_request)
          begin
            body.peek # start the request
          rescue StopIteration
            # the S3 object is empty
          end

          content_length = Integer(req.context.http_response.headers["Content-Length"])
          chunks         = Enumerator.new { |y| loop { y << body.next } }

          [chunks, content_length]
        end
      end

      # The file is copyable if it's on S3 and on the same Amazon account.
      def copyable?(io)
        io.is_a?(UploadedFile) &&
        io.storage.is_a?(Storage::S3) &&
        io.storage.client.config.access_key_id == client.config.access_key_id
      end

      # Deletes all objects in fewest requests possible (S3 only allows 1000
      # objects to be deleted at once).
      def delete_objects(objects)
        objects.each_slice(1000) do |objects_batch|
          delete_params = { objects: objects_batch.map { |object| { key: object.key } } }
          bucket.delete_objects(delete: delete_params)
        end
      end

      # Returns object key with potential prefix.
      def object_key(id)
        [*prefix, id].join("/")
      end

      # Adds support for Aws::S3::Encryption::Client.
      module ClientSideEncryption
        attr_reader :encryption_client

        # Save the encryption client and continue initialization with normal
        # client.
        def initialize(client: nil, **options)
          return super unless client.class.name.start_with?("Aws::S3::Encryption")

          super(client: client.client, **options)
          @encryption_client = client
        end

        private

        # Encryption client doesn't support multipart uploads, so we always use
        # #put_object.
        def put(io, id, **options)
          return super unless encryption_client

          encryption_client.put_object(body: io, bucket: bucket.name, key: object_key(id), **options)
        end

        def get(id, **options)
          return super unless encryption_client

          # Encryption client v2 warns against streaming download, so we first
          # download all content into a file.
          tempfile = Tempfile.new("shrine-s3", binmode: true)
          response = encryption_client.get_object(response_target: tempfile, bucket: bucket.name, key: object_key(id), **options)
          tempfile.rewind

          chunks = Enumerator.new do |yielder|
            begin
              yielder << tempfile.read(16*1024) until tempfile.eof?
            ensure
              tempfile.close!
            end
          end

          [chunks, tempfile.size]
        end
      end

      prepend ClientSideEncryption
    end
  end
end
