class Uploadie
  module Plugins
    module Location
      def self.configure(uploadie, generator:)
        raise ArgumentError, ":processor must be a proc or a symbol" if !(generator.is_a?(Proc) || generator.is_a?(Symbol))
        uploadie.opts[:location_generator] = generator
      end

      module InstanceMethods
        private

        def _generate_location(io, context)
          generator = self.class.opts[:location_generator]
          generator = method(generator) if generator.is_a?(Symbol)
          result = instance_exec(io, context, &generator)
          raise Error, "generated location should be a String, and was #{result.inspect}" if not result.is_a?(String)
          result
        end
      end
    end

    register_plugin(:location, Location)
  end
end
