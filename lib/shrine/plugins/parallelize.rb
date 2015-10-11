require "thread/pool"

Thread::Pool.abort_on_exception = true

class Shrine
  module Plugins
    # The parallelize plugin parallelizes your uploads and deletes using the
    # [thread] gem.
    #
    #     plugin :parallelize
    #
    # This plugin is generally only useful as an addition to the versions
    # plugin, where multiple files are being uploaded and deleted at once. Note
    # that it's not possible for this plugin to parallelize processing, but it
    # should be easy to do that manually.
    #
    # By default a pool of 3 threads will be used, but you can change that:
    #
    #     plugin :parallelize, threads: 5
    #
    # [thread]: https://github.com/meh/ruby-thread
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

        def copy(io, context)
          context[:thread_pool].process { super }
        end

        def move(io, context)
          context[:thread_pool].process { super }
        end

        def remove(uploaded_file, context)
          context[:thread_pool].process { super }
        end

        # We initialize a thread pool with configured number of threads.
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
