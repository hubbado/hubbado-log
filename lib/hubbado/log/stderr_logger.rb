require_relative '../log'

module Hubbado
  class Log
    # Prints a log line where a person watching a run can see it. Not required by
    # `hubbado/log`: which handlers exist is the process's to decide, and this is the one
    # handler with no application to belong to, because $stderr is owned by nobody.
    class StderrLogger < LogHandler
      # Where a stacktrace earns its space on a terminal. The logger synthesises one for `warn`
      # too, but a warning is a condition to examine rather than a failure to trace, and its
      # message already names the field and value — so a sweep that warns per row would bury
      # itself in Ruby stack to solve a problem stderr does not have.
      FAILURE_SEVERITIES = %i[error fatal unknown].freeze

      def initialize(io: $stderr)
        super()

        @io = io
      end

      def log(subject, severity, message, data = nil, stacktrace = nil)
        io.puts("#{severity.to_s.upcase} #{subject}: #{message}")
        io.puts(data.is_a?(Exception) ? data.full_message : data.inspect) unless data.nil?
        io.puts(stacktrace) if print_stacktrace?(severity, data, stacktrace)
      end

      private

      attr_reader :io

      # An exception is excluded because the logger sets the stacktrace to its `full_message` —
      # the identical string already printed from the data — so honouring both would print the
      # backtrace twice.
      def print_stacktrace?(severity, data, stacktrace)
        return false if stacktrace.nil?
        return false if data.is_a?(Exception)

        FAILURE_SEVERITIES.include?(severity.to_sym)
      end
    end
  end
end
