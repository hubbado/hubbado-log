module Hubbado
  class Log
    class Configuration
      # Tracing is off until somebody asks for it, which is what lets a debug line be written
      # for a human watching one run without it also reaching every unattended log.
      DEFAULT_LEVEL = :info

      attr_accessor :loggers
      attr_reader :level

      def initialize(level: nil)
        @loggers = []
        self.level = level || DEFAULT_LEVEL
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
