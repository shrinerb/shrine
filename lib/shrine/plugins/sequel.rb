require "sequel"

class Shrine
  module Plugins
    module Sequel
      def self.configure(uploader, promote: nil)
        uploader.opts[:promote] = promote
      end

      module AttachmentMethods
        def initialize(name, *args)
          super
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def validate
              super
              #{name}_attacher.errors.each do |message|
                errors.add(:#{name}, message)
              end
            end

            def before_save
              super
              #{name}_attacher.save
              #{name}_attacher._promote
            end

            def after_save
              super
              #{name}_attacher.replace
            end

            def after_destroy
              super
              #{name}_attacher.destroy
            end
          RUBY
        end
      end

      module AttacherMethods
        def _promote
          if promote?(get)
            if shrine_class.opts[:promote]
              shrine_class.opts[:promote].call(get, context)
            else
              promote(get)
            end
          end
        end

        private

        def changed?(uploaded_file)
          record.reload unless in_transaction?
          super
        end

        def in_transaction?
          record.class.db.in_transaction?
        end
      end
    end

    register_plugin(:sequel, Sequel)
  end
end
