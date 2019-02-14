# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/module_include.md] on GitHub.
    #
    # [doc/plugins/module_include.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/module_include.md
    module ModuleInclude
      module ClassMethods
        def attachment_module(mod = nil, &block)
          module_include(self::Attachment, mod, &block)
        end

        def attacher_module(mod = nil, &block)
          module_include(self::Attacher, mod, &block)
        end

        def file_module(mod = nil, &block)
          module_include(self::UploadedFile, mod, &block)
        end

        private

        def module_include(klass, mod, &block)
          mod ||= Module.new(&block)
          klass.include(mod)
        end
      end
    end

    register_plugin(:module_include, ModuleInclude)
  end
end
