module Hubbado
  class Log
    class Configuration
      # Tracing is off until somebody asks for it, which is what lets a debug message be written
      # for a human watching one run without it also reaching every unattended log.
      DEFAULT_LEVEL = :info

      attr_reader :loggers
      attr_reader :level
      attr_reader :tags

      # The configuration is the process's rather than a class's, so a subclass of Log reads the
      # one a command wrote and there is a single set of handlers to build from it.
      #
      # The one place the environment is read. A command names its level and tags here or not at
      # all, and everything downstream is handed the value rather than the variable.
      def self.instance
        @instance ||= new(level: ENV[LEVEL_VARIABLE], tags: ENV[TAGS_VARIABLE])
      end

      def initialize(level: nil, tags: nil)
        self.loggers = []
        self.level = level || DEFAULT_LEVEL
        self.tags = tags
      end

      # Whatever the block leaves behind is what the process is configured for, and the handlers
      # are built again from it. Named here rather than left to the caller, because a block is
      # free to mutate the list of loggers in place and never reach the writer below.
      def change
        yield self

        @log_handlers = nil
      end

      # The handlers themselves, one set for the process. A handler holds what it has been told,
      # so a second set built somewhere else would be a second place to read it back from.
      def log_handlers
        @log_handlers ||= loggers.map(&:new)
      end

      def loggers=(value)
        @log_handlers = nil
        @loggers = value
      end

      # Takes the LOG_TAGS string as readily as a list, so nothing upstream has to know the
      # syntax in order to hand a value in.
      def tags=(value)
        @tags = Tags.parse(value)
      end

      # A name rather than a severity is answered with the default instead of an exception.
      # The level is set from LOG_LEVEL, which Eventide's log gem owns across hubbado_saas and
      # writes its own vocabulary into ("_min"): a variable this gem shares is not a variable
      # it can refuse.
      def level=(value)
        named = value.to_s.downcase.to_sym

        @level = SEVERITIES.key?(named) ? named : DEFAULT_LEVEL
      end
    end
  end
end
