module Hubbado
  class Log
    # Whether the operator asked to be shown a message. A handler that prints asks this; one that
    # reports an incident does not, so narrowing a log cannot silence a failure.
    class Display
      # Both have to pass: a tag cannot raise a message above the level, nor the level rescue one
      # the list leaves out.
      def self.shows?(severity, tags = nil)
        config = Log.config

        return false if SEVERITIES.fetch(severity.to_sym) < SEVERITIES.fetch(config.level)

        config.tags.write?(tags)
      end
    end
  end
end
