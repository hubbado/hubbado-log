module Hubbado
  class Log
    class Logger
      attr_accessor :log_handlers
      attr_accessor :subject

      def initialize(subject, log_handlers = [], level: nil, tags: nil)
        self.subject = subject
        self.log_handlers = Array(log_handlers)
        @level = level
        @tags = tags
      end

      # A logger built without one follows the configuration, which is every logger the gem
      # builds itself: `Log.configure` names neither, so a class using the Dependency module
      # takes whatever the process was configured for.
      def level = @level || Log.config.level

      # Named per logger as well as per process, as the level is and as Eventide's log gem has
      # it, so one component can be read without turning up everything around it.
      def tags = @tags.nil? ? Log.config.tags : Tags.parse(@tags)

      def log(severity, msg, data = nil, tag: nil, tags: nil)
        unless SEVERITIES.keys.include? severity.to_sym
          raise ArgumentError, "Unknown serverity #{severity}"
        end

        # Read after the severity is checked, never before: the level decides what is printed,
        # not what may be said, so quietening a logger must not turn a typo into silence.
        return if SEVERITIES.fetch(severity.to_sym) < SEVERITIES.fetch(level)

        # Singular and plural are both accepted and both kept, following Eventide's log gem,
        # where real call sites use either and occasionally hand an array to the singular one.
        #
        # Named as symbols, because that is what LOG_TAGS is parsed into: a String here would
        # match nothing and its message would go missing with nothing said about it.
        message_tags = (Array(tags) + Array(tag)).map { |name| name.to_s.to_sym }

        # Both filters have to pass. A tag cannot raise a message above the level, and the level
        # cannot rescue one the list leaves out.
        #
        # `self.` because the `tags:` keyword above shadows the reader.
        return unless self.tags.write?(message_tags)

        stacktrace = if data.is_a?(Exception)
                       data.full_message
                     elsif STACKTRACE_SEVERITIES.include?(severity)
                       format_stacktrace Kernel.caller
                     end

        # A copy each, so a handler that appends a tag of its own does not change what the next
        # one is given.
        log_handlers.each do |handler|
          handler.log(subject, severity, msg, data, stacktrace, tags: message_tags.dup)
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
