# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/dynamic_storage.md] on GitHub.
    #
    # [doc/plugins/dynamic_storage.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/dynamic_storage.md
    module DynamicStorage
      def self.configure(uploader)
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
