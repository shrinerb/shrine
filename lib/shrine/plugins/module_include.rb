class Shrine
  module Plugins
    # The module_include plugin allows you to extend Shrine's core classes for
    # the given uploader with modules/methods.
    #
    #     plugin :module_include
    #
    # To add a module to a core class, call the appropriate method:
    #
    #     Shrine.attachment_module CustomAttachmentMethods
    #     Shrine.attacher_module CustomAttacherMethods
    #     Shrine.file_module CustomFileMethods
    #
    # Alternatively you can pass in a block (which internally creates a module):
    #
    #     Shrine.file_module do
    #       def base64
    #         Base64.encode64(read)
    #       end
    #     end
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
