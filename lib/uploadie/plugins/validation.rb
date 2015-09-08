class Uploadie
  module Plugins
    module Validation
      module InstanceMetods
        class ValidationFailed < Uploadie::Error
          attr_reader :errors

          def initialize(errors)
            @errors = errors
          end
        end

        def _upload(io, type)
          validator = Validator.new(io)
          if validate(validator)
        end

        def validate(validator, type)
        end

        class Validator
        end
      end
    end

    register_plugin(:validation, Validation)
  end
end
