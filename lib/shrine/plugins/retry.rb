class Shrine
  module Plugins
    module Retry
      def self.configure(uploader, tries:)
        uploader.opts[:retry_tries] = tries
      end

      module InstanceMethods
        private

        def put(io, location, tries: opts[:retry_tries])
          super(io, location)
        rescue
          retry if (tries -= 1) > 0
          raise
        end
      end
    end

    register_plugin(:retry, Retry)
  end
end
