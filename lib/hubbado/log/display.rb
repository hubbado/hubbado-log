module Hubbado
  class Log
    # Whether the operator asked to be shown a message. A handler that writes where a person reads
    # asks this; one that reports an incident does not, so narrowing a log cannot silence a failure.
    #
    # Read from the configuration on every call, so a process that reconfigures mid-run is honoured.
    class Display
      # Both have to pass: a tag cannot raise a message above the level, and the level cannot
      # rescue one the list leaves out.
      def self.shows?(severity, tags = [])
        return false if SEVERITIES.fetch(severity.to_sym) < SEVERITIES.fetch(Log.config.level)

        Log.config.tags.write?(Array(tags))
      end
    end
  end
end
