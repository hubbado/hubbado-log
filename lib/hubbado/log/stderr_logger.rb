require_relative '../log'

module Hubbado
  class Log
    # Prints a log line where a person watching a run can see it.
    class StderrLogger < LogHandler
      # Where a stacktrace earns its space on a terminal. The logger synthesises one for `warn`
      # too, but a warning is a condition to examine rather than a failure to trace, and its
      # message already names the field and value — so a sweep that warns per row would bury
      # itself in Ruby stack to solve a problem stderr does not have.
      FAILURE_SEVERITIES = %i[error fatal unknown].freeze

      def initialize(io: nil)
        super()

        @io = io
      end

      # One write, because a line and the detail under it belong together. Three writes let a
      # second thread put its own line between them, and a stacktrace filed under the wrong
      # message is worse than no stacktrace.
      def log(subject, severity, message, data = nil, stacktrace = nil, tags = nil)
        return unless Display.shows?(severity, tags)

        lines = ["#{severity.to_s.upcase} #{subject}: #{message}"]
        lines << detail(data, stacktrace) unless data.nil?
        lines << stacktrace if print_stacktrace?(severity, data, stacktrace)

        io.puts(lines.join("\n"))
      end

      private

      # Read rather than stored, so a process that rebinds $stderr after the log system built
      # its handlers is written to rather than the stream it replaced.
      def io = @io || $stderr

      # An exception carries its own backtrace, and the logger has already rendered it into the
      # stacktrace argument — so that string is reused rather than rendered a second time.
      def detail(data, stacktrace)
        return data.inspect unless data.is_a?(::Exception)

        stacktrace || data.full_message
      end

      # An exception is excluded because its `full_message` is printed from the data above, so
      # honouring the argument as well would print the backtrace twice.
      def print_stacktrace?(severity, data, stacktrace)
        return false if stacktrace.nil?
        return false if data.is_a?(::Exception)

        FAILURE_SEVERITIES.include?(severity.to_sym)
      end
    end
  end
end
