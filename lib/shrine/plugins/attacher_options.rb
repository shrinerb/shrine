# frozen_string_literal: true

class Shrine
  module Plugins
    module AttacherOptions
      module AttacherMethods
        def initialize(**options)
          super
          @options = {}
        end

        def attach_options(options = nil)
          handle_option(:attach, options)
        end

        def promote_options(options = nil)
          handle_option(:promote, options)
        end

        def destroy_options(options = nil)
          handle_option(:destroy, options)
        end

        def attach_cached(io, **options)
          super(io, **attach_options, **options)
        end

        def attach(io, **options)
          super(io, **attach_options, **options)
        end

        def promote_cached(**options)
          super(**promote_options, **options)
        end

        def destroy_attached(**options)
          super(**destroy_options, **options)
        end

        private

        def handle_option(name, options)
          if options
            @options[name] ||= {}
            @options[name].merge!(options)
          else
            @options[name] || {}
          end
        end
      end
    end

    register_plugin(:attacher_options, AttacherOptions)
  end
end
