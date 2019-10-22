# frozen_string_literal: true

class Shrine
  # Core class that handles attaching files. It uses Shrine and
  # Shrine::UploadedFile objects internally.
  class Attacher
    @shrine_class = ::Shrine

    module ClassMethods
      # Returns the Shrine class that this attacher class is namespaced
      # under.
      attr_accessor :shrine_class

      # Since Attacher is anonymously subclassed when Shrine is subclassed,
      # and then assigned to a constant of the Shrine subclass, make inspect
      # reflect the likely name for the class.
      def inspect
        "#{shrine_class.inspect}::Attacher"
      end

      # Initializes the attacher from a data hash generated from `Attacher#data`.
      #
      #     attacher = Attacher.from_data({ "id" => "...", "storage" => "...", "metadata" => { ... } })
      #     attacher.file #=> #<Shrine::UploadedFile>
      def from_data(data, **options)
        attacher = new(**options)
        attacher.load_data(data)
        attacher
      end
    end

    module InstanceMethods
      # Returns the attached uploaded file.
      attr_reader :file

      # Returns options that are automatically forwarded to the uploader.
      # Can be modified with additional data.
      attr_reader :context

      # Initializes the attached file, temporary and permanent storage.
      def initialize(file: nil, cache: :cache, store: :store)
        @file    = file
        @cache   = cache
        @store   = store
        @context = {}
      end

      # Returns the temporary storage identifier.
      def cache_key; @cache; end
      # Returns the permanent storage identifier.
      def store_key; @store; end

      # Returns the uploader that is used for the temporary storage.
      def cache; shrine_class.new(cache_key); end
      # Returns the uploader that is used for the permanent storage.
      def store; shrine_class.new(store_key); end

      # Calls #attach_cached, but skips if value is an empty string (this is
      # useful when the uploaded file comes from form fields). Forwards any
      # additional options to #attach_cached.
      #
      #     attacher.assign(File.open(...))
      #     attacher.assign(File.open(...), metadata: { "foo" => "bar" })
      #     attacher.assign('{"id":"...","storage":"cache","metadata":{...}}')
      #     attacher.assign({ "id" => "...", "storage" => "cache", "metadata" => {} })
      #
      #     # ignores the assignment when a blank string is given
      #     attacher.assign("")
      def assign(value, **options)
        return if value == "" # skip empty hidden field

        attach_cached(value, **options)
      end

      # Sets an existing cached file, or uploads an IO object to temporary
      # storage and sets it via #attach. Forwards any additional options to
      # #attach.
      #
      #     # upload file to temporary storage and set the uploaded file.
      #     attacher.attach_cached(File.open(...))
      #
      #     # foward additional options to the uploader
      #     attacher.attach_cached(File.open(...), metadata: { "foo" => "bar" })
      #
      #     # sets an existing cached file from JSON data
      #     attacher.attach_cached('{"id":"...","storage":"cache","metadata":{...}}')
      #
      #     # sets an existing cached file from Hash data
      #     attacher.attach_cached({ "id" => "...", "storage" => "cache", "metadata" => {} })
      def attach_cached(value, **options)
        if value.is_a?(String) || value.is_a?(Hash)
          change(cached(value, **options), **options)
        else
          attach(value, storage: cache_key, action: :cache, **options)
        end
      end

      # Uploads given IO object and changes the uploaded file.
      #
      #     # uploads the file to permanent storage
      #     attacher.attach(io)
      #
      #     # uploads the file to specified storage
      #     attacher.attach(io, storage: :other_store)
      #
      #     # forwards additional options to the uploader
      #     attacher.attach(io, upload_options: { acl: "public-read" }, metadata: { "foo" => "bar" })
      #
      #     # removes the attachment
      #     attacher.attach(nil)
      def attach(io, storage: store_key, **options)
        file = upload(io, storage, **options) if io

        change(file, **options)
      end

      # Deletes any previous file and promotes newly attached cached file.
      # It also clears any dirty tracking.
      #
      #     # promoting cached file
      #     attacher.assign(io)
      #     attacher.cached? #=> true
      #     attacher.finalize
      #     attacher.stored?
      #
      #     # deleting previous file
      #     previous_file = attacher.file
      #     previous_file.exists? #=> true
      #     attacher.assign(io)
      #     attacher.finalize
      #     previous_file.exists? #=> false
      #
      #     # clearing dirty tracking
      #     attacher.assign(io)
      #     attacher.changed? #=> true
      #     attacher.finalize
      #     attacher.changed? #=> false
      def finalize
        destroy_previous
        promote_cached
        remove_instance_variable(:@previous) if changed?
      end

      # Plugins can override this if they want something to be done in a
      # "before save" callback.
      def save
      end

      # If a new cached file has been attached, uploads it to permanent storage.
      # Any additional options are forwarded to #promote.
      #
      #     attacher.assign(io)
      #     attacher.cached? #=> true
      #     attacher.promote_cached
      #     attacher.stored? #=> true
      def promote_cached(**options)
        promote(**options) if promote?
      end

      # Uploads current file to permanent storage and sets the stored file.
      #
      #     attacher.cached? #=> true
      #     attacher.promote
      #     attacher.stored? #=> true
      def promote(storage: store_key, **options)
        set upload(file, storage, action: :store, **options)
      end

      # Delegates to `Shrine.upload`, passing the #context.
      #
      #     # upload file to specified storage
      #     attacher.upload(io, :store) #=> #<Shrine::UploadedFile>
      #
      #     # pass additional options for the uploader
      #     attacher.upload(io, :store, metadata: { "foo" => "bar" })
      def upload(io, storage = store_key, **options)
        shrine_class.upload(io, storage, **context, **options)
      end

      # If a new file was attached, deletes previously attached file if any.
      #
      #     previous_file = attacher.file
      #     attacher.attach(file)
      #     attacher.destroy_previous
      #     previous_file.exists? #=> false
      def destroy_previous
        @previous.destroy_attached if changed?
      end

      # Destroys the attached file if it exists and is uploaded to permanent
      # storage.
      #
      #     attacher.file.exists? #=> true
      #     attacher.destroy_attached
      #     attacher.file.exists? #=> false
      def destroy_attached
        destroy if destroy?
      end

      # Destroys the attachment.
      #
      #     attacher.file.exists? #=> true
      #     attacher.destroy
      #     attacher.file.exists? #=> false
      def destroy
        file&.delete
      end

      # Sets the uploaded file with dirty tracking, and runs validations.
      #
      #     attacher.change(uploaded_file)
      #     attacher.file #=> #<Shrine::UploadedFile>
      #     attacher.changed? #=> true
      def change(file, **)
        @previous = dup unless @file == file
        set(file)
      end

      # Sets the uploaded file.
      #
      #     attacher.set(uploaded_file)
      #     attacher.file #=> #<Shrine::UploadedFile>
      #     attacher.changed? #=> false
      def set(file)
        self.file = file
      end

      # Returns the attached file.
      #
      #     # when a file is attached
      #     attacher.get #=> #<Shrine::UploadedFile>
      #
      #     # when no file is attached
      #     attacher.get #=> nil
      def get
        file
      end

      # If a file is attached, returns the uploaded file URL, otherwise returns
      # nil. Any options are forwarded to the storage.
      #
      #     attacher.file = file
      #     attacher.url #=> "https://..."
      #
      #     attacher.file = nil
      #     attacher.url #=> nil
      def url(**options)
        file&.url(**options)
      end

      # Returns whether the attachment has changed.
      #
      #     attacher.changed? #=> false
      #     attacher.attach(file)
      #     attacher.changed? #=> true
      def changed?
        instance_variable_defined?(:@previous)
      end

      # Returns whether a file is attached.
      #
      #     attacher.attach(io)
      #     attacher.attached? #=> true
      #
      #     attacher.attach(nil)
      #     attacher.attached? #=> false
      def attached?
        !!file
      end

      # Returns whether the file is uploaded to temporary storage.
      #
      #     attacher.cached?       # checks current file
      #     attacher.cached?(file) # checks given file
      def cached?(file = self.file)
        uploaded?(file, cache_key)
      end

      # Returns whether the file is uploaded to permanent storage.
      #
      #     attacher.stored?       # checks current file
      #     attacher.stored?(file) # checks given file
      def stored?(file = self.file)
        uploaded?(file, store_key)
      end

      # Generates serializable data for the attachment.
      #
      #     attacher.data #=> { "id" => "...", "storage" => "...", "metadata": { ... } }
      def data
        file&.data
      end

      # Loads the uploaded file from data generated by `Attacher#data`.
      #
      #     attacher.file #=> nil
      #     attacher.load_data({ "id" => "...", "storage" => "...", "metadata" => { ... } })
      #     attacher.file #=> #<Shrine::UploadedFile>
      def load_data(data)
        @file = data && uploaded_file(data)
      end

      # Saves the given uploaded file to an instance variable.
      #
      #     attacher.file = uploaded_file
      #     attacher.file #=> #<Shrine::UploadedFile>
      def file=(file)
        unless file.is_a?(Shrine::UploadedFile) || file.nil?
          fail ArgumentError, "expected file to be a Shrine::UploadedFile or nil, got #{file.inspect}"
        end

        @file = file
      end

      # Returns attached file or raises an exception if no file is attached.
      def file!
        file or fail Error, "no file is attached"
      end

      # Converts JSON or Hash data into a Shrine::UploadedFile object.
      #
      #     attacher.uploaded_file('{"id":"...","storage":"...","metadata":{...}}')
      #     #=> #<Shrine::UploadedFile ...>
      #
      #     attacher.uploaded_file({ "id" => "...", "storage" => "...", "metadata" => {} })
      #     #=> #<Shrine::UploadedFile ...>
      def uploaded_file(value)
        shrine_class.uploaded_file(value)
      end

      # Returns the Shrine class that this attacher's class is namespaced
      # under.
      def shrine_class
        self.class.shrine_class
      end

      private

      # Converts a String or Hash value into an UploadedFile object and ensures
      # it's uploaded to temporary storage.
      #
      #     # from JSON data
      #     attacher.cached('{"id":"...","storage":"cache","metadata":{...}}')
      #     #=> #<Shrine::UploadedFile>
      #
      #     # from Hash data
      #     attacher.cached({ "id" => "...", "storage" => "cache", "metadata" => { ... } })
      #     #=> #<Shrine::UploadedFile>
      def cached(value, **)
        uploaded_file = uploaded_file(value)

        # reject files not uploaded to temporary storage, because otherwise
        # attackers could hijack other users' attachments
        unless cached?(uploaded_file)
          fail Shrine::Error, "expected cached file, got #{uploaded_file.inspect}"
        end

        uploaded_file
      end

      # Whether attached file should be uploaded to permanent storage.
      def promote?
        changed? && cached?
      end

      # Whether attached file should be deleted.
      def destroy?
        attached? && !cached?
      end

      # Returns whether the file is uploaded to specified storage.
      def uploaded?(file, storage_key)
        file&.storage_key == storage_key
      end
    end

    extend ClassMethods
    include InstanceMethods
  end
end
