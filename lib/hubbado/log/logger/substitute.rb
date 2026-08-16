module Hubbado
  class Log
    class Logger
      # What a logger was told rather than what it wrote. Extended onto a mimic of Logger, so a
      # class under test is handed something that answers as a logger and keeps what it was given.
      module Substitute
        Line = Data.define(:severity, :message, :data)

        # Everything about what a class said, in order. Named with a severity, only what it said
        # at that one.
        #
        # A severity reaches a logger two ways: as the method, from the generated severity
        # methods, or as #log's first argument. Both are compared as symbols, because #log takes
        # a String as readily and passes on what it was given.
        def logged(severity = nil)
          lines = invocations.map { |invocation| line(invocation) }

          return lines if severity.nil?

          lines.select { |written| written.severity == severity.to_s.to_sym }
        end

        # What a class said, where #logged is everything about it.
        def messages(severity = nil) = logged(severity).map(&:message)

        # Whether, where #logged and #messages ask what. Without a severity, whether anything was
        # written at all.
        def logged?(severity = nil) = !logged(severity).empty?

        private

        def line(invocation)
          arguments = invocation.arguments

          Line.new(
            severity: severity(invocation).to_s.to_sym,
            message: arguments[:msg],
            data: arguments[:data]
          )
        end

        def severity(invocation)
          return invocation.arguments.fetch(:severity) if invocation.method_name == :log

          invocation.method_name
        end
      end
    end
  end
end
