class Uploadie
  module Plugins
    module DefaultUrl
      def self.configure(uploadie, generator:)
        raise ArgumentError, ":generator must be a proc or a symbol" if !generator.is_a?(Proc) && !generator.is_a?(Symbol)
        uploadie.opts[:default_url] = generator
      end

      module AttacherMethods
        def url(*args)
          super || _default_url(*args)
        end

        private

        def _default_url(version = nil)
          generator = uploadie_class.opts[:default_url]
          generator = store.method(generator) if generator.is_a?(Symbol)

          context = {record: record, name: name}
          context.update(version: version) if version

          store.instance_exec(context, &generator)
        end
      end
    end

    register_plugin(:default_url, DefaultUrl)
  end
end
