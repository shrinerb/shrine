require "thread/pool"

Thread::Pool.abort_on_exception = true

class Shrine
  module Plugins
    module Parallelize
      def self.configure(uploader, threads: 3)
        uploader.opts[:parallelize_threads] = threads
      end

      module InstanceMethods
        def store(io, context = {})
          with_pool { |pool| super(io, thread_pool: pool, **context) }
        end

        def delete(uploaded_file, context = {})
          with_pool { |pool| super(uploaded_file, thread_pool: pool, **context) }
        end

        private

        def put(io, context)
          context[:thread_pool].process { super }
        end

        def remove(uploaded_file, context)
          context[:thread_pool].process { super }
        end

        def with_pool
          pool = Thread.pool(opts[:parallelize_threads])
          result = yield pool
          pool.shutdown
          result
        end
      end
    end

    register_plugin(:parallelize, Parallelize)
  end
end
