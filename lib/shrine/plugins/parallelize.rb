require "thread"

class Shrine
  module Plugins
    # The parallelize plugin parallelizes your uploads and deletes using
    # threads.
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
          def initialize(thread_count)
            @thread_count = thread_count
            @tasks = Queue.new
          end

          def enqueue(&task)
            @tasks.enq(task)
          end

          def perform
            threads = @thread_count.times.map { spawn_thread }
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
