require "forwardable"

class Shrine
  module Plugins
    module BoundedRackRequest
      InputTooLarge = Class.new(Error)

      module ClassMethods
        def bounded_rack_request(request, max_body_size)
          body_size   = Integer(request.content_length) if request.content_length
          body_size ||= request.body.size if request.body.respond_to?(:size)

          raise InputTooLarge, "request body is too large" if body_size && body_size > max_body_size

          env = request.env

          bounded_rack_input = BoundedInput.new(env["rack.input"], max_body_size)
          bounded_rack_env   = env.merge("rack.input" => bounded_rack_input)

          request.class.new(bounded_rack_env)
        end
      end

      class BoundedInput
        def initialize(input, limit)
          @input      = input
          @limit      = limit
          @bytes_read = 0
        end

        def read(*args)
          chunk = @input.read(*args)

          @bytes_read += chunk.bytesize if chunk
          raise InputTooLarge, "request body is too large" if @bytes_read > @limit

          chunk
        end

        def rewind
          @input.rewind
          @bytes_read = 0
        end

        extend Forwardable
        delegate [:gets, :each, :close] => :@input
      end
    end

    register_plugin(:bounded_rack_request, BoundedRackRequest)
  end
end
