# frozen_string_literal: true

class Shrine
  # Core class which handles attaching files to model instances.
  # Base implementation is defined in InstanceMethods and ClassMethods.
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

      # Block that is executed in context of Shrine::Attacher during
      # validation. Example:
      #
      #     Shrine::Attacher.validate do
      #       if get.size > 5*1024*1024
      #         errors << "is too big (max is 5 MB)"
      #       end
      #     end
      def validate(&block)
        define_method(:validate_block, &block)
        private :validate_block
      end
    end

    module InstanceMethods
      # Returns the uploader that is used for the temporary storage.
      attr_reader :cache

      # Returns the uploader that is used for the permanent storage.
      attr_reader :store

      # Returns the context that will be sent to the uploader when uploading
      # and deleting. Can be modified with additional data to be sent to the
      # uploader.
      attr_reader :context

      # Returns an array of validation errors created on file assignment in
      # the `Attacher.validate` block.
      attr_reader :errors

      # Initializes the necessary attributes.
      def initialize(record, name, cache: :cache, store: :store)
        @cache   = shrine_class.new(cache)
        @store   = shrine_class.new(store)
        @context = { record: record, name: name }
        @errors  = []
      end

      # Returns the model instance associated with the attacher.
      def record; context[:record]; end

      # Returns the attachment name associated with the attacher.
      def name;   context[:name];   end

      # Receives the attachment value from the form. It can receive an
      # already cached file as a JSON string, otherwise it assumes that it's
      # an IO object and uploads it to the temporary storage. The cached file
      # is then written to the attachment attribute in the JSON format.
      def assign(value, **options)
        if value.is_a?(String)
          return if value == "" || !cached?(uploaded_file(value))
          assign_cached(uploaded_file(value))
        else
          uploaded_file = cache!(value, action: :cache, **options) if value
          set(uploaded_file)
        end
      end

      # Accepts a Shrine::UploadedFile object and writes it to the attachment
      # attribute. It then runs file validations, and records that the
      # attachment has changed.
      def set(uploaded_file)
        file = get
        @old = file unless uploaded_file == file
        _set(uploaded_file)
        validate
      end

      # Runs the validations defined by `Attacher.validate`.
      def validate
        errors.clear
        validate_block if get
      end

      # Returns true if a new file has been attached.
      def changed?
        instance_variable_defined?(:@old)
      end
      alias attached? changed?

      # Plugins can override this if they want something to be done before
      # save.
      def save
      end

      # Deletes the old file and promotes the new one. Typically this should
      # be called after saving the model instance.
      def finalize
        return if !instance_variable_defined?(:@old)
        replace
        remove_instance_variable(:@old)
        _promote(action: :store) if cached?
      end

      # Delegates to #promote, overriden for backgrounding.
      def _promote(uploaded_file = get, **options)
        promote(uploaded_file, **options)
      end

      # Uploads the cached file to store, and writes the stored file to the
      # attachment attribute.
      def promote(uploaded_file = get, **options)
        stored_file = store!(uploaded_file, **options)
        result = swap(stored_file) or _delete(stored_file, action: :abort)
        result
      end

      # Calls #update, overriden in ORM plugins, and returns true if the
      # attachment was successfully updated.
      def swap(uploaded_file)
        update(uploaded_file)
        uploaded_file if uploaded_file == get
      end

      # Deletes the previous attachment that was replaced, typically called
      # after the model instance is saved with the new attachment.
      def replace
        _delete(@old, action: :replace) if @old && !cached?(@old)
      end

      # Deletes the current attachment, typically called after destroying the
      # record.
      def destroy
        file = get
        _delete(file, action: :destroy) if file && !cached?(file)
      end

      # Delegates to #delete!, overriden for backgrounding.
      def _delete(uploaded_file, **options)
        delete!(uploaded_file, **options)
      end

      # Returns the URL to the attached file if it's present. It forwards any
      # given URL options to the storage.
      def url(**options)
        get.url(**options) if read
      end

      # Returns true if attachment is present and cached.
      def cached?(file = get)
        file && cache.uploaded?(file)
      end

      # Returns true if attachment is present and stored.
      def stored?(file = get)
        file && store.uploaded?(file)
      end

      # Returns a Shrine::UploadedFile instantiated from the data written to
      # the attachment attribute.
      def get
        uploaded_file(read) if read
      end

      # Reads from the `<attachment>_data` attribute on the model instance.
      # It returns nil if the value is blank.
      def read
        value = record.send(data_attribute)
        convert_after_read(value) unless value.nil? || value.empty?
      end

      # Uploads the file using the #cache uploader, passing the #context.
      def cache!(io, **options)
        Shrine.deprecation("Sending :phase to Attacher#cache! is deprecated and will not be supported in Shrine 3. Use :action instead.") if options[:phase]
        cache.upload(io, context.merge(_equalize_phase_and_action(options)))
      end

      # Uploads the file using the #store uploader, passing the #context.
      def store!(io, **options)
        Shrine.deprecation("Sending :phase to Attacher#store! is deprecated and will not be supported in Shrine 3. Use :action instead.") if options[:phase]
        store.upload(io, context.merge(_equalize_phase_and_action(options)))
      end

      # Deletes the file using the uploader, passing the #context.
      def delete!(uploaded_file, **options)
        Shrine.deprecation("Sending :phase to Attacher#delete! is deprecated and will not be supported in Shrine 3. Use :action instead.") if options[:phase]
        store.delete(uploaded_file, context.merge(_equalize_phase_and_action(options)))
      end

      # Enhances `Shrine.uploaded_file` with the ability to recognize uploaded
      # files as JSON strings.
      def uploaded_file(object, &block)
        shrine_class.uploaded_file(object, &block)
      end

      # The name of the attribute on the model instance that is used to store
      # the attachment data. Defaults to `<attachment>_data`.
      def data_attribute
        :"#{name}_data"
      end

      # Returns the Shrine class that this attacher's class is namespaced
      # under.
      def shrine_class
        self.class.shrine_class
      end

      private

      # Assigns a cached file.
      def assign_cached(cached_file)
        set(cached_file)
      end

      # Writes the uploaded file to the attachment attribute. Overriden in ORM
      # plugins to additionally save the model instance.
      def update(uploaded_file)
        _set(uploaded_file)
      end

      # Performs validation actually.
      # This method is redefined with `Attacher.validate`.
      def validate_block
      end

      # Converts the UploadedFile to a data hash and writes it to the
      # attribute.
      def _set(uploaded_file)
        data = convert_to_data(uploaded_file) if uploaded_file
        write(data ? convert_before_write(data) : nil)
      end

      # Writes to the `<attachment>_data` attribute on the model instance.
      def write(value)
        record.send(:"#{data_attribute}=", value)
      end

      # Returns the data hash of the given UploadedFile.
      def convert_to_data(uploaded_file)
        uploaded_file.data
      end

      # Returns the hash value dumped to JSON.
      def convert_before_write(value)
        value.to_json
      end

      # Returns the read value unchanged.
      def convert_after_read(value)
        value
      end

      # Temporary method used for transitioning from :phase to :action.
      def _equalize_phase_and_action(options)
        options[:phase]  = options[:action] if options.key?(:action)
        options[:action] = options[:phase] if options.key?(:phase)
        options
      end
    end

    extend ClassMethods
    include InstanceMethods
  end
end
