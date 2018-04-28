# frozen_string_literal: true

require "shrine"
begin
  require "aws-sdk-s3"
  if Gem::Version.new(Aws::S3::GEM_VERSION) < Gem::Version.new("1.2.0")
    raise "Shrine::Storage::S3 requires aws-sdk-s3 version 1.2.0 or above"
  end
rescue LoadError => exception
  begin
    require "aws-sdk"
    Shrine.deprecation("Using aws-sdk 2.x is deprecated and support for it will be removed in Shrine 3, use the new aws-sdk-s3 gem instead.")
    Aws.eager_autoload!(services: ["S3"])
  rescue LoadError
    raise exception
  end
end

require "down/chunked_io"
require "uri"
require "cgi"
require "tempfile"

class Shrine
  module Storage
    # The S3 storage handles uploads to Amazon S3 service, using the
    # [aws-sdk-s3] gem:
    #
    #     gem "aws-sdk-s3", "~> 1.2"
    #
    # It can be initialized by providing the bucket name and credentials:
    #
    #     s3 = Shrine::Storage::S3.new(
    #       access_key_id: "abc",
    #       secret_access_key: "xyz",
    #       region: "eu-west-1",
    #       bucket: "my-app",
    #     )
    #
    # The core features of this storage requires the following AWS permissions:
    # `s3:ListBucket`, `s3:PutObject`, `s3:GetObject`, and `s3:DeleteObject`.
    # If you have additional upload options configured such as setting object
    # ACLs, then additional permissions may be required.
    #
    # The storage exposes the underlying Aws objects:
    #
    #     s3.client #=> #<Aws::S3::Client>
    #     s3.client.access_key_id #=> "abc"
    #     s3.client.secret_access_key #=> "xyz"
    #     s3.client.region #=> "eu-west-1"
    #
    #     s3.bucket #=> #<Aws::S3::Bucket>
    #     s3.bucket.name #=> "my-app"
    #
    #     s3.object("key") #=> #<Aws::S3::Object>
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
    #     Shrine::Storage::S3.new(upload_options: { acl: "private" }, **s3_options)
    #
    # These options will be passed to aws-sdk-s3's methods for [uploading],
    # [copying] and [presigning].
    #
    # You can also generate upload options per upload with the `upload_options`
    # plugin
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
    # or when using the uploader directly
    #
    #     uploader.upload(file, upload_options: { acl: "private" })
    #
    # Note that, unlike the `:upload_options` storage option, upload options
    # given on the uploader level won't be forwarded for generating presigns,
    # since presigns are generated using the storage directly.
    #
    # ## URL options
    #
    # This storage supports various URL options that will be forwarded from
    # uploaded file.
    #
    #     s3.url(public: true)   # public URL without signed parameters
    #     s3.url(download: true) # forced download URL
    #
    # All other options are forwarded to the aws-sdk-s3 gem:
    #
    #     s3.url(expires_in: 15)
    #     s3.url(virtual_host: true)
    #
    # ## CDN
    #
    # If you're using a CDN with S3 like Amazon CloudFront, you can specify
    # the `:host` option to `#url`:
    #
    #     s3.url("image.jpg", host: "http://abc123.cloudfront.net")
    #     #=> "http://abc123.cloudfront.net/image.jpg"
    #
    # You have the `:host` option passed automatically for every URL with the
    # `default_url_options` plugin.
    #
    #     plugin :default_url_options, store: { host: "http://abc123.cloudfront.net" }
    #
    # ## Accelerate endpoint
    #
    # To use Amazon S3's [Transfer Acceleration] feature, you can change the
    # `:endpoint` of the underlying client to the accelerate endpoint, and this
    # will be applied both to regular and presigned uploads, as well as
    # download URLs.
    #
    #     Shrine::Storage::S3.new(endpoint: "https://s3-accelerate.amazonaws.com")
    #
    # ## Presigns
    #
    # This storage can generate presigns for direct uploads to Amazon S3, and
    # it accepts additional options which are passed to aws-sdk-s3. There are
    # three places in which you can specify presign options:
    #
    # * in `:upload_options` option on this storage
    # * in `presign_endpoint` plugin through `:presign_options`
    # * in `Storage::S3#presign` by forwarding options
    #
    # ## Large files
    #
    # The aws-sdk-s3 gem has the ability to automatically use multipart
    # upload/copy for larger files, splitting the file into multiple chunks
    # and uploading/copying them in parallel.
    #
    # By default any files that are uploaded will use the multipart upload
    # if they're larger than 15MB, and any files that are copied will use the
    # multipart copy if they're larger than 150MB, but you can change the
    # thresholds via `:multipart_threshold`.
    #
    #     thresholds = { upload: 30*1024*1024, copy: 200*1024*1024 }
    #     Shrine::Storage::S3.new(multipart_threshold: thresholds, **s3_options)
    #
    # If you want to change how many threads aws-sdk-s3 will use for multipart
    # upload/copy, you can use the `upload_options` plugin to specify
    # `:thread_count`.
    #
    #     plugin :upload_options, store: -> (io, context) do
    #       { thread_count: 5 }
    #     end
    #
    # ## Clearing cache
    #
    # If you're using S3 as a cache, you will probably want to periodically
    # delete old files which aren't used anymore. S3 has a built-in way to do
    # this, read [this article][object lifecycle] for instructions.
    #
    # Alternatively you can periodically call the `#clear!` method:
    #
    #     # deletes all objects that were uploaded more than 7 days ago
    #     s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 }
    #
    # [uploading]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#put-instance_method
    # [copying]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#copy_from-instance_method
    # [presigning]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_post-instance_method
    # [aws-sdk-s3]: https://github.com/aws/aws-sdk-ruby/tree/master/gems/aws-sdk-s3
    # [Transfer Acceleration]: http://docs.aws.amazon.com/AmazonS3/latest/dev/transfer-acceleration.html
    # [object lifecycle]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#put-instance_method
    class S3
      MIN_PART_SIZE = 5 * 1024 * 1024 # 5MB

      attr_reader :client, :bucket, :prefix, :host, :upload_options

      # Initializes a storage for uploading to S3. All options are forwarded to
      # [`Aws::S3::Client#initialize`], except the following:
      #
      # :bucket
      # : (Required). Name of the S3 bucket.
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
      def initialize(bucket:, prefix: nil, host: nil, upload_options: {}, multipart_threshold: {}, **s3_options)
        Shrine.deprecation("The :host option to Shrine::Storage::S3#initialize is deprecated and will be removed in Shrine 3. Pass :host to S3#url instead, you can also use default_url_options plugin.") if host
        resource = Aws::S3::Resource.new(**s3_options)

        if multipart_threshold.is_a?(Integer)
          Shrine.deprecation("Accepting the :multipart_threshold S3 option as an integer is deprecated, use a hash with :upload and :copy keys instead, e.g. {upload: 15*1024*1024, copy: 150*1024*1024}")
          multipart_threshold = { upload: multipart_threshold }
        end
        multipart_threshold = { upload: 15*1024*1024, copy: 100*1024*1024 }.merge(multipart_threshold)

        @bucket = resource.bucket(bucket) or fail(ArgumentError, "the :bucket option was nil")
        @client = resource.client
        @prefix = prefix
        @host = host
        @upload_options = upload_options
        @multipart_threshold = multipart_threshold
      end

      # Returns an `Aws::S3::Resource` object.
      def s3
        Shrine.deprecation("Shrine::Storage::S3#s3 that returns an Aws::S3::Resource is deprecated, use Shrine::Storage::S3#client which returns an Aws::S3::Client object.")
        Aws::S3::Resource.new(client: @client)
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
        options[:content_disposition] = "inline; filename=\"#{filename}\"" if filename

        options.update(@upload_options)
        options.update(upload_options)

        options[:content_disposition] = encode_content_disposition(options[:content_disposition]) if options[:content_disposition]

        if copyable?(io)
          copy(io, id, **options)
        else
          bytes_uploaded = put(io, id, **options)
          shrine_metadata["size"] ||= bytes_uploaded
        end
      end

      # Downloads the file from S3, and returns a `Tempfile`. Any additional
      # options are forwarded to [`Aws::S3::Object#get`].
      #
      # [`Aws::S3::Object#get`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#get-instance_method
      def download(id, **options)
        tempfile = Tempfile.new(["shrine-s3", File.extname(id)], binmode: true)
        (object = object(id)).get(response_target: tempfile, **options)
        tempfile.singleton_class.instance_eval { attr_accessor :content_type }
        tempfile.content_type = object.content_type
        tempfile.tap(&:open)
      rescue
        tempfile.close! if tempfile
        raise
      end

      # Returns a `Down::ChunkedIO` object representing the S3 object. Any
      # additional options are forwarded to [`Aws::S3::Object#get`].
      #
      # [`Aws::S3::Object#get`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#get-instance_method
      def open(id, **options)
        object = object(id)
        io = Down::ChunkedIO.new(chunks: object.enum_for(:get, **options), data: { object: object })
        io.size = object.content_length
        io
      end

      # Returns true file exists on S3.
      def exists?(id)
        object(id).exists?
      end

      # Returns the presigned URL to the file.
      #
      # :public
      # :  Controls whether the URL is signed (`false`) or unsigned (`true`).
      #    Note that for unsigned URLs the S3 bucket need to be modified to allow
      #    public URLs. Defaults to `false`.
      #
      # :host
      # :  This option replaces the host part of the returned URL, and is
      #    typically useful for setting CDN hosts (e.g.
      #    `http://abc123.cloudfront.net`)
      #
      # :download
      # :  If set to `true`, creates a "forced download" link, which means that
      #    the browser will never display the file and always ask the user to
      #    download it.
      #
      # All other options are forwarded to [`Aws::S3::Object#presigned_url`] or
      # [`Aws::S3::Object#public_url`].
      #
      # [`Aws::S3::Object#presigned_url`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method
      # [`Aws::S3::Object#public_url`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#public_url-instance_method
      def url(id, download: nil, public: nil, host: self.host, **options)
        options[:response_content_disposition] ||= "attachment" if download
        options[:response_content_disposition] = encode_content_disposition(options[:response_content_disposition]) if options[:response_content_disposition]

        if public
          url = object(id).public_url(**options)
        else
          url = object(id).presigned_url(:get, **options)
        end

        if host
          uri = URI.parse(url)
          uri.path = uri.path.match(/^\/#{bucket.name}/).post_match unless uri.host.include?(bucket.name) || client.config.force_path_style
          url = URI.join(host, uri.request_uri).to_s
        end

        url
      end

      # Returns URL, params and headers for direct uploads. By default it
      # generates data for a POST request, calling [`Aws::S3::Object#presigned_post`].
      # You can also specify `method: :put` to generate data for a PUT request,
      # using [`Aws::S3::Object#presigned_url`]. Any additional options are
      # forwarded to the underlying AWS SDK method.
      #
      # [`Aws::S3::Object#presigned_post`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_post-instance_method
      # [`Aws::S3::Object#presigned_url`]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_url-instance_method
      def presign(id, method: :post, **options)
        options = @upload_options.merge(options)
        options[:content_disposition] = encode_content_disposition(options[:content_disposition]) if options[:content_disposition]

        if method == :post
          presigned_post = object(id).presigned_post(options)

          Struct.new(:method, :url, :fields).new(method, presigned_post.url, presigned_post.fields)
        else
          url = object(id).presigned_url(method, options)

          # When any of these options are specified, the corresponding request
          # headers must be included in the upload request.
          headers = {}
          headers["Content-Length"]      = options[:content_length]      if options[:content_length]
          headers["Content-Type"]        = options[:content_type]        if options[:content_type]
          headers["Content-Disposition"] = options[:content_disposition] if options[:content_disposition]
          headers["Content-Encoding"]    = options[:content_encoding]    if options[:content_encoding]
          headers["Content-Language"]    = options[:content_language]    if options[:content_language]
          headers["Content-MD5"]         = options[:content_md5]         if options[:content_md5]

          { method: method, url: url, headers: headers }
        end
      end

      # Deletes the file from the storage.
      def delete(id)
        object(id).delete
      end

      # If block is given, deletes all objects from the storage for which the
      # block evaluates to true. Otherwise deletes all objects from the storage.
      #
      #     s3.clear!
      #     # or
      #     s3.clear! { |object| object.last_modified < Time.now - 7*24*60*60 }
      def clear!(&block)
        objects_to_delete = Enumerator.new do |yielder|
          bucket.objects(prefix: prefix).each do |object|
            yielder << object if block.nil? || block.call(object)
          end
        end

        delete_objects(objects_to_delete)
      end

      # Returns an `Aws::S3::Object` for the given id.
      def object(id)
        bucket.object([*prefix, id].join("/"))
      end

      # Catches the deprecated `#stream` method.
      def method_missing(name, *args)
        if name == :stream
          Shrine.deprecation("Shrine::Storage::S3#stream is deprecated over calling #each_chunk on S3#open.")
          object = object(*args)
          object.get { |chunk| yield chunk, object.content_length }
        else
          super
        end
      end

      private

      # Copies an existing S3 object to a new location. Uses multipart copy for
      # large files.
      def copy(io, id, **options)
        # pass :content_length on multipart copy to avoid an additional HEAD request
        options = { multipart_copy: true, content_length: io.size }.merge!(options) if io.size && io.size >= @multipart_threshold[:copy]
        object(id).copy_from(io.storage.object(io.id), **options)
      end

      # Uploads the file to S3. Uses multipart upload for large files.
      def put(io, id, **options)
        if io.respond_to?(:path)
          path = io.path
        elsif io.is_a?(UploadedFile) && defined?(Storage::FileSystem) && io.storage.is_a?(Storage::FileSystem)
          path = io.storage.path(io.id).to_s
        end

        if path
          # use `upload_file` for files because it can do multipart upload
          options = { multipart_threshold: @multipart_threshold[:upload] }.merge!(options)
          object(id).upload_file(path, **options)
          File.size(path)
        else
          io.open if io.is_a?(UploadedFile)

          if io.respond_to?(:size) && io.size
            object(id).put(body: io, **options)
            io.size
          else
            # IO has unknown size, so we have to use multipart upload
            multipart_put(io, id, **options)
          end
        end
      end

      # Uploads the file to S3 using multipart upload.
      def multipart_put(io, id, **options)
        MultipartUploader.new(object(id)).upload(io, **options)
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

      # Upload requests will fail if filename has non-ASCII characters, because
      # of how S3 generates signatures, so we URI-encode them. Most browsers
      # should automatically URI-decode filenames when downloading.
      def encode_content_disposition(content_disposition)
        content_disposition.sub(/(?<=filename=").+(?=")/) do |filename|
          CGI.escape(filename).gsub("+", " ")
        end
      end

      # Uploads IO objects of unknown size using the multipart API.
      class MultipartUploader
        def initialize(object)
          @object = object
        end

        # Initiates multipart upload, uploads IO content into multiple parts,
        # and completes the multipart upload. If an exception is raised, the
        # multipart upload is automatically aborted.
        def upload(io, **options)
          multipart_upload = @object.initiate_multipart_upload(**options)

          parts = upload_parts(multipart_upload, io)
          bytes_uploaded = parts.inject(0) { |size, part| size + part.delete(:size) }

          multipart_upload.complete(multipart_upload: { parts: parts })

          bytes_uploaded
        rescue
          multipart_upload.abort if multipart_upload
          raise
        end

        # Uploads parts until the IO object has reached EOF.
        def upload_parts(multipart_upload, io)
          1.step.inject([]) do |parts, part_number|
            parts << upload_part(multipart_upload, io, part_number)
            break parts if io.eof?
            parts
          end
        end

        # Uploads at most 5MB of IO content into a single multipart part.
        def upload_part(multipart_upload, io, part_number)
          Tempfile.create("shrine-s3-part-#{part_number}") do |body|
            multipart_part = multipart_upload.part(part_number)

            IO.copy_stream(io, body, MIN_PART_SIZE)
            body.rewind

            response = multipart_part.upload(body: body)

            { part_number: part_number, size: body.size, etag: response.etag }
          end
        end
      end
    end
  end
end
