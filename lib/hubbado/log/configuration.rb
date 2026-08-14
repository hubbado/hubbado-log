module Hubbado
  class Log
    class Configuration
      LEVEL_VARIABLE = "LOG_LEVEL".freeze

      # Tracing is off until somebody asks for it, which is what lets a debug line be written
      # for a human watching one run without it also reaching every unattended log.
      DEFAULT_LEVEL = :info

      attr_accessor :loggers
      attr_writer :level

      def initialize(env: ENV)
        @loggers = []
        @env = env
      end

      # LOG_LEVEL is shared with Eventide's log gem, which writes names this one does not know
      # ("_min") and sets it for its own reasons. A name that is not a severity here leaves the
      # level where it would have been, rather than stopping a process over a variable another
      # library owns.
      def level
        @level ||= SEVERITIES.key?(named_level) ? named_level : DEFAULT_LEVEL
      end

      private

      def named_level = @env[LEVEL_VARIABLE].to_s.downcase.to_sym
    end
  end
end
