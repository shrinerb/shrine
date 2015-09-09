class Uploadie
  module Plugins
    module RemoveAttachment
      module AttachmentMethods
        def initialize(name, *args)
          super

          module_eval <<-RUBY, __FILE__, __LINE__ + 1
            def remove_#{name}=(value)
              #{name}_attacher.remove = value
            end

            def remove_#{name}
              #{name}_attacher.remove
            end
          RUBY
        end
      end

      module AttacherMethods
        def remove=(value)
          @remove = value
          set(nil) if remove?
        end

        def remove
          @remove
        end

        private

        def remove?
          remove && remove != "" && remove !~ /\A0|false$\z/
        end
      end
    end

    register_plugin(:remove_attachment, RemoveAttachment)
  end
end
