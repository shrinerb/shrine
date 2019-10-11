# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation can be found on https://shrinerb.com/docs/plugins/dynamic_storage
    module DynamicStorage
      def self.configure(uploader)
        uploader.opts[:dynamic_storage] ||= { resolvers: {} }
      end

      module ClassMethods
        def storage(regex, &block)
          opts[:dynamic_storage][:resolvers][regex] = block
        end

        def find_storage(name)
          resolve_dynamic_storage(name) or super
        end

        private

        def resolve_dynamic_storage(name)
          opts[:dynamic_storage][:resolvers].each do |regex, block|
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
