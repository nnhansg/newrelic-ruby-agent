# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

module NewRelic
  module Agent
    module Threading
      class AgentThread

        def self.create(label, &blk)
          ::NewRelic::Agent.logger.debug("Creating New Relic thread: #{label}")
          wrapped_blk = Proc.new do
            begin
              blk.call
            rescue => e
              ::NewRelic::Agent.logger.debug("Thread #{label} exited with error", e)
            ensure
              ::NewRelic::Agent.logger.debug("Exiting New Relic thread: #{label}")
            end
          end

          thread = backing_thread_class.new(&wrapped_blk)
          thread[:newrelic_label] = label
          thread
        end

        # Simplifies testing if we don't directly use ::Thread.list, so keep
        # the accessor for it here on AgentThread to use and stub.
        def self.list
          backing_thread_class.list
        end

        def self.bucket_thread(thread, profile_agent_code)
          if thread.key?(:newrelic_label)
            profile_agent_code ? :agent : :ignore
          elsif TransactionState.in_background_transaction?(thread)
            :background
          elsif TransactionState.in_request_transaction?(thread)
            :request
          else
            :other
          end
        end

        def self.scrub_backtrace(thread, profile_agent_code)
          begin
            bt = thread.backtrace
          rescue Exception => e
            ::NewRelic::Agent.logger.debug("Failed to backtrace #{thread.inspect}: #{e.class.name}: #{e.to_s}")
          end
          return nil unless bt
          bt.reject! { |t| t.include?('/newrelic_rpm-') } unless profile_agent_code
          bt
        end

        # To allow tests to swap out Thread for a synchronous alternative,
        # surface the backing class we'll use from the class level.
        @backing_thread_class = ::Thread

        def self.backing_thread_class
          @backing_thread_class
        end

        def self.backing_thread_class=(clazz)
          @backing_thread_class = clazz
        end
      end
    end
  end
end
