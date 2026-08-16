module Hubbado
  class Log
    class Logger
      # What a logger was told rather than what it wrote. Extended onto a mimic of Logger, so a
      # class under test is handed something that answers as a logger and keeps what it was given.
      module Substitute
        # Every message, in order. Named with a severity, only the ones written at it.
        #
        # A severity reaches a logger two ways: as the method, from the generated severity
        # methods, or as #log's first argument. Both are compared as symbols, because #log takes
        # a String as readily and passes on what it was given.
        def messages(severity = nil)
          written = invocations.map { |invocation| message(invocation) }

          return written if severity.nil?

          written.select { |message| message.fetch(:severity) == severity.to_s.to_sym }
        end

        # Whether, where #messages asks which. Without a severity, whether anything was written
        # at all.
        def logged?(severity = nil) = !messages(severity).empty?

        private

        def message(invocation)
          arguments = invocation.arguments

          {
            severity: severity(invocation).to_s.to_sym,
            message: arguments[:msg],
            data: arguments[:data]
          }
        end

        def severity(invocation)
          return invocation.arguments.fetch(:severity) if invocation.method_name == :log

          invocation.method_name
        end
      end
    end
  end
end
