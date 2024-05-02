module Hubbado
  class Log
    class Logger
      attr_accessor :log_handlers
      attr_accessor :subject

      def initialize(subject, log_handlers = [])
        self.subject = subject
        self.log_handlers = Array(log_handlers)
      end

      def log(severity, msg, data = nil)
        unless SEVERITIES.keys.include? severity.to_sym
          raise ArgumentError, "Unknown serverity #{severity}"
        end

        stacktrace = if data.is_a?(Exception)
                       data.full_message
                     elsif STACKTRACE_SEVERITIES.include?(severity)
                       format_stacktrace Kernel.caller
                     end

        log_handlers.each do |handler|
          handler.log(subject, severity, msg, data, stacktrace)
        end
      end

      private

      def format_stacktrace(stacktrace)
        stacktrace.join("\n")
      end
    end
  end
end
