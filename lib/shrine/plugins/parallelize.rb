require "thread"

class Shrine
  module Plugins
    # The `parallelize` plugin parallelizes uploads and deletes of multiple
    # versions using threads.
    #
    #     plugin :parallelize
    #
    # By default a pool of 3 threads will be used, but you can change that:
    #
    #     plugin :parallelize, threads: 5
    module Parallelize
      def self.configure(uploader, opts = {})
        uploader.opts[:parallelize_threads] = opts.fetch(:threads, uploader.opts.fetch(:parallelize_threads, 3))
      end

      def self.load_dependencies(uploader, opts = {})
        uploader.plugin :hooks
      end

      module InstanceMethods
        def around_store(io, context)
          with_pool { |pool| super(io, context.update(thread_pool: pool)) }
        end

        def around_delete(uploaded_file, context)
          with_pool { |pool| super(uploaded_file, context.update(thread_pool: pool)) }
        end

        private

        def put(io, context)
          context[:thread_pool].enqueue { super }
        end

        def remove(uploaded_file, context)
          context[:thread_pool].enqueue { super }
        end

        # We initialize a thread pool with configured number of threads.
        def with_pool(&block)
          pool = ThreadPool.new(opts[:parallelize_threads])
          result = yield pool
          pool.perform
          result
        end
      end

      class ThreadPool
        def initialize(size)
          @size = size
          @tasks = Queue.new
        end

        def enqueue(&task)
          @tasks.enq(task)
        end

        def perform
          threads = @size.times.map { spawn_thread }
          threads.each(&:join)
        end

        private

        def spawn_thread
          Thread.new do
            Thread.current.abort_on_exception = true
            loop do
              task = @tasks.deq(true) rescue break
              task.call
            end
          end
        end
      end
    end

    register_plugin(:parallelize, Parallelize)
  end
end
