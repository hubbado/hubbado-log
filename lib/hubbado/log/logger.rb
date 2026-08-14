module Hubbado
  class Log
    class Logger
      attr_accessor :log_handlers
      attr_accessor :subject

      def initialize(subject, log_handlers = [], level: nil)
        self.subject = subject
        self.log_handlers = Array(log_handlers)
        @level = level
      end

      # A logger built without one follows the configuration, which is every logger the gem
      # builds itself: `Log.configure` names no level, so a class using the Dependency module
      # takes whatever the process was configured for.
      def level = @level || Log.config.level

      def log(severity, msg, data = nil)
        unless SEVERITIES.keys.include? severity.to_sym
          raise ArgumentError, "Unknown serverity #{severity}"
        end

        # Read after the severity is checked, never before: the level decides what is printed,
        # not what may be said, so quietening a logger must not turn a typo into silence.
        return if SEVERITIES.fetch(severity.to_sym) < SEVERITIES.fetch(level)

        stacktrace = if data.is_a?(Exception)
                       data.full_message
                     elsif STACKTRACE_SEVERITIES.include?(severity)
                       format_stacktrace Kernel.caller
                     end

        log_handlers.each do |handler|
          handler.log(subject, severity, msg, data, stacktrace)
        end
      end

      SEVERITIES.each_key do |severity|
        define_method severity do |msg, data = nil|
          log severity, msg, data
        end
      end

      private

      def format_stacktrace(stacktrace)
        stacktrace.join("\n")
      end
    end
  end
end
