module Hubbado
  class Log
    class Logger
      attr_accessor :log_handlers
      attr_accessor :subject

      def initialize(subject, log_handlers = [])
        self.subject = subject
        self.log_handlers = Array(log_handlers)
      end

      def log(severity, msg, data = nil, tag: nil, tags: nil)
        unless SEVERITIES.keys.include? severity.to_sym
          raise ArgumentError, "Unknown serverity #{severity}"
        end

        # Singular and plural are both accepted and both kept, following Eventide's log gem,
        # where real call sites use either and occasionally hand an array to the singular one.
        #
        # Named as symbols, because that is what LOG_TAGS is parsed into: a String here would
        # match nothing and its message would go missing with nothing said about it.
        message_tags = (Array(tags) + Array(tag)).map { |name| name.to_s.to_sym }

        stacktrace = if data.is_a?(Exception)
                       data.full_message
                     elsif STACKTRACE_SEVERITIES.include?(severity)
                       format_stacktrace Kernel.caller
                     end

        log_handlers.each do |handler|
          handler.log(subject, severity, msg, data, stacktrace, message_tags)
        end
      end

      SEVERITIES.each_key do |severity|
        define_method severity do |msg, data = nil, tag: nil, tags: nil|
          log severity, msg, data, tag: tag, tags: tags
        end
      end

      private

      def format_stacktrace(stacktrace)
        stacktrace.join("\n")
      end
    end
  end
end
