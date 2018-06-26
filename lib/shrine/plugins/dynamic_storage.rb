# frozen_string_literal: true

class Shrine
  module Plugins
    # The `dynamic_storage` plugin allows you to register a storage using a
    # regex, and evaluate the storage class dynamically depending on the regex.
    #
    # Example:
    #
    #     plugin :dynamic_storage
    #
    #     storage /store_(\w+)/ do |match|
    #       Shrine::Storages::S3.new(bucket: match[1])
    #     end
    #
    # The above example uses S3 storage where the bucket name depends on the
    # storage name suffix. For example, `:store_foo` will use S3 storage which
    # saves files to the bucket "foo". The block is yielded an instance of
    # `MatchData`.
    #
    # This can be useful in combination with the `default_storage` plugin.
    module DynamicStorage
      def self.configure(uploader, options = {})
        uploader.opts[:dynamic_storages] ||= {}
      end

      module ClassMethods
        def dynamic_storages
          opts[:dynamic_storages]
        end

        def storage(regex, &block)
          dynamic_storages[regex] = block
        end

        def find_storage(name)
          resolve_dynamic_storage(name) or super
        end

        private

        def resolve_dynamic_storage(name)
          dynamic_storages.each do |regex, block|
            if match = name.to_s.match(regex)
              return block.call(match)
            end
          end
          nil
        end
      end
    end

    register_plugin(:dynamic_storage, DynamicStorage)
  end
end
