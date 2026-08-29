require_relative '../log'

module Hubbado
  class Log
    # Writes a log line into a Rails application's own log.
    class RailsLogger < LogHandler
      # Rails has no logger method below debug, so the gem's trace is written as one. A handler
      # passing it straight through raises NoMethodError on the first trace line it is handed.
      RAILS_SEVERITIES = { trace: :debug }.freeze

      def initialize(rails_logger: nil)
        super()

        @rails_logger = rails_logger
      end

      def log(subject, severity, message, data = nil, stacktrace = nil, tags = nil)
        return unless Display.shows?(severity, tags)

        rails_severity = RAILS_SEVERITIES.fetch(severity.to_sym, severity)

        rails_logger.send(rails_severity, "#{subject}: #{message}")

        details(data, stacktrace).each do |detail|
          rails_logger.send(rails_severity, detail)
        end
      end

      private

      # Read rather than stored, because Rails replaces its logger during boot and a handler
      # built before that would keep writing to the one it replaced.
      def rails_logger = @rails_logger || ::Rails.logger

      # A Rails log is read after the fact, and by machine as often as by a person, so the
      # stacktrace is written whatever the severity — where a terminal withholds it below error
      # to stay readable.
      #
      # An exception is one entry rather than two: its `full_message` carries the message that
      # `inspect` would print, so writing both writes the message twice.
      def details(data, stacktrace)
        return [stacktrace || data.full_message] if data.is_a?(::Exception)

        [data&.inspect, stacktrace].compact
      end
    end
  end
end
