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
    #       bucket: "my-app", # required
    #       access_key_id: "abc",
    #       secret_access_key: "xyz",
    #       region: "eu-west-1",
    #     )
    #
    # The core features of this storage require the following AWS permissions:
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
    # ## Public uploads
    #
    # By default, uploaded S3 objects will have private visibility, meaning
    # they can only be accessed via signed expiring URLs generated using your
    # private S3 credentials. If you would like to generate public URLs, you
    # can tell S3 storage to make uploads public:
    #
    #     s3 = Shrine::Storage::S3.new(public: true, **s3_options)
    #
    #     s3.upload(io, "key") # uploads with "public-read" ACL
    #     s3.url("key")        # returns public (unsigned) object URL
    #
    # ## Prefix
    #
    # The `:prefix` option can be specified for uploading all files inside
    # a specific S3 prefix (folder), which is useful when using S3 for both
    # cache and store:
    #
    #     Shrine::Storage::S3.new(prefix: "cache", **s3_options)
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
    # If you would like to [serve private content via CloudFront], you need to
    # sign the object URLs with a special signer, such as
    # [`Aws::CloudFront::UrlSigner`] provided by the `aws-sdk-cloudfront` gem.
    # The S3 storage initializer accepts a `:signer` block, which you can use
    # to call your signer:
    #
    #
    #     require "aws-sdk-cloudfront"
    #
    #     signer = Aws::CloudFront::UrlSigner.new(
    #       key_pair_id:      "cf-keypair-id",
    #       private_key_path: "./cf_private_key.pem"
    #     )
    #
    #     Shrine::Storage::S3.new(signer: signer.method(:signed_url))
    #     # or
    #     Shrine::Storage::S3.new(signer: -> (url, **options) { signer.signed_url(url, **options) })
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
    # ## Request Rate and Performance Guidelines
    #
    # Amazon S3 automatically scales to high request rates. For example, your
    # application can achieve at least 3,500 PUT/POST/DELETE and 5,500 GET
    # requests per second per prefix in a bucket (a prefix is a top-level
    # "directory" in the bucket). If your app needs to support higher request
    # rates to S3 than that, you can scale exponentially by using more prefixes.
    #
    # [uploading]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#put-instance_method
    # [copying]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#copy_from-instance_method
    # [presigning]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#presigned_post-instance_method
    # [aws-sdk-s3]: https://github.com/aws/aws-sdk-ruby/tree/master/gems/aws-sdk-s3
    # [Transfer Acceleration]: http://docs.aws.amazon.com/AmazonS3/latest/dev/transfer-acceleration.html
    # [object lifecycle]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#put-instance_method
    # [serve private content via CloudFront]: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PrivateContent.html
    # [`Aws::CloudFront::UrlSigner`]: https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/CloudFront/UrlSigner.html
    class S3
      MIN_PART_SIZE = 5 * 1024 * 1024 # 5MB

      attr_reader :client, :bucket, :prefix, :host, :upload_options, :signer, :public

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
      def initialize(bucket:, prefix: nil, host: nil, upload_options: {}, multipart_threshold: {}, signer: nil, public: nil, **s3_options)
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
        @signer = signer
        @public = public
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
        options[:acl] = "public-read" if public

        options.merge!(@upload_options)
        options.merge!(upload_options)

        options[:content_disposition] = encode_content_disposition(options[:content_disposition]) if options[:content_disposition]

        if copyable?(io)
          copy(io, id, **options)
        else
          bytes_uploaded = put(io, id, **options)
          shrine_metadata["size"] ||= bytes_uploaded
        end
      end

      # Downloads the file from S3 and returns a `Tempfile`. The download will
      # be automatically retried up to 3 times. Any additional options are
      # forwarded to [`Aws::S3::Object#get`].
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

      # Returns a `Down::ChunkedIO` object that downloads S3 object content
      # on-demand. By default, read content will be cached onto disk so that
      # it can be rewinded, but if you don't need that you can pass
      # `rewindable: false`.
      #
      # Any additional options are forwarded to [`Aws::S3::Object#get`].
      #
      # [`Aws::S3::Object#get`]: http://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Object.html#get-instance_method
      def open(id, rewindable: true, **options)
        object = object(id)
        io = Down::ChunkedIO.new(
          chunks:     object.enum_for(:get, **options),
          rewindable: rewindable,
          data:       { object: object },
        )
        io.size = object.content_length
        io
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
      def url(id, download: nil, public: self.public, host: self.host, **options)
        options[:response_content_disposition] ||= "attachment" if download
        options[:response_content_disposition] = encode_content_disposition(options[:response_content_disposition]) if options[:response_content_disposition]

        if public || signer
          url = object(id).public_url(**options)
        else
          url = object(id).presigned_url(:get, **options)
        end

        if host
          uri = URI.parse(url)
          uri.path = uri.path.match(/^\/#{bucket.name}/).post_match unless uri.host.include?(bucket.name) || client.config.force_path_style
          url = URI.join(host, uri.request_uri).to_s
        end

        if signer
          url = signer.call(url, **options)
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
      def presign(id, method: :post, **presign_options)
        options = {}
        options[:acl] = "public-read" if public

        options.merge!(@upload_options)
        options.merge!(presign_options)

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
        bytes_uploaded = nil

        if (path = extract_path(io))
          # use `upload_file` for files because it can do multipart upload
          options = { multipart_threshold: @multipart_threshold[:upload] }.merge!(options)
          object(id).upload_file(path, **options)
          bytes_uploaded = File.size(path)
        else
          io.to_io if io.is_a?(UploadedFile) # open if not already opened

          if io.respond_to?(:size) && io.size && (io.size <= @multipart_threshold[:upload] || !object(id).respond_to?(:upload_stream))
            object(id).put(body: io, **options)
            bytes_uploaded = io.size
          elsif object(id).respond_to?(:upload_stream)
            # `upload_stream` uses multipart upload
            object(id).upload_stream(tempfile: true, **options) do |write_stream|
              bytes_uploaded = IO.copy_stream(io, write_stream)
            end
          else
            Shrine.deprecation "Uploading a file of unknown size with aws-sdk-s3 older than 1.14 is deprecated and will be removed in Shrine 3. Update to aws-sdk-s3 1.14 or higher."

            Tempfile.create("shrine-s3", binmode: true) do |file|
              bytes_uploaded = IO.copy_stream(io, file.path)
              object(id).upload_file(file.path, **options)
            end
          end
        end

        bytes_uploaded
      end

      def extract_path(io)
        if io.respond_to?(:path)
          io.path
        elsif io.is_a?(UploadedFile) && defined?(Storage::FileSystem) && io.storage.is_a?(Storage::FileSystem)
          io.storage.path(io.id).to_s
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

      # Upload requests will fail if filename has non-ASCII characters, because
      # of how S3 generates signatures, so we URI-encode them. Most browsers
      # should automatically URI-decode filenames when downloading.
      def encode_content_disposition(content_disposition)
        content_disposition.sub(/(?<=filename=").+(?=")/) do |filename|
          CGI.escape(filename).gsub("+", " ")
        end
      end
    end
  end
end
