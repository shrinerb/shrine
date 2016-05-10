require "thread"

class Shrine
  module Plugins
    # The parallelize plugin parallelizes uploads and deletes when handling
    # versions, using threads.
    #
    #     plugin :parallelize
    #
    # By default a pool of 3 threads will be used, but you can change that:
    #
    #     plugin :parallelize, threads: 5
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
    end

    register_plugin(:parallelize, Parallelize)
  end
end
