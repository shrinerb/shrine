class Shrine
  module Plugins
    # The `metadata_attributes` plugin allows you to sync attachment metadata
    # to additional record attributes. You can provide a hash of mappings to
    # the plugin call itself or the `Attacher.metadata_attributes` method:
    #
    #     plugin :metadata_attributes, :size => :size, :mime_type => :type
    #     # or
    #     plugin :metadata_attributes
    #     Attacher.metadata_attributes, :size => :size, :mime_type => :type
    #
    # The above configuration will sync `size` metadata field to
    # `<attachment>_size` record attribute, and `mime_type` metadata field to
    # `<attachment>_type` record attribute.
    #
    #     user.avatar = image
    #     user.avatar.metadata["size"]      #=> 95724
    #     user.avatar_size                  #=> 95724
    #     user.avatar.metadata["mime_type"] #=> "image/jpeg"
    #     user.avatar_type                  #=> "image/jpeg"
    #
    #     user.avatar = nil
    #     user.avatar_size #=> nil
    #     user.avatar_type #=> nil
    #
    # If any corresponding metadata attribute doesn't exist on the record, that
    # metadata sync will be silently skipped.
    module MetadataAttributes
      def self.configure(uploader, mappings = {})
        uploader.opts[:metadata_attributes_mappings] ||= {}
        uploader.opts[:metadata_attributes_mappings].merge!(mappings)
      end

      module AttacherClassMethods
        def metadata_attributes(mappings)
          shrine_class.opts[:metadata_attributes_mappings].merge!(mappings)
        end
      end

      module AttacherMethods
        def assign(value)
          super
          cached_file = get

          shrine_class.opts[:metadata_attributes_mappings].each do |source, destination|
            next unless record.respond_to?(:"#{name}_#{destination}=")

            if cached_file
              record.send(:"#{name}_#{destination}=", cached_file.metadata[source.to_s])
            else
              record.send(:"#{name}_#{destination}=", nil)
            end
          end
        end
      end
    end

    register_plugin(:metadata_attributes, MetadataAttributes)
  end
end
