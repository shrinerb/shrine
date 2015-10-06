require "active_record"

class Shrine
  module Plugins
    module Activerecord
      def self.configure(uploader, promote: nil)
        uploader.opts[:promote] = promote
      end

      module AttachmentMethods
        def included(model)
          super

          model.class_eval <<-RUBY, __FILE__, __LINE__ + 1
            validate do
              #{@name}_attacher.errors.each do |message|
                errors.add(:#{@name}, message)
              end
            end

            before_save do
              #{@name}_attacher.save
              #{@name}_attacher._promote
            end

            after_save do
              #{@name}_attacher.replace
            end

            after_destroy do
              #{@name}_attacher.destroy
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
          record.class.connection.transaction_open?
        end
      end
    end

    register_plugin(:activerecord, Activerecord)
  end
end
