require_relative '../log'

module Hubbado
  class Log
    # Writes a log line into a Rails application's own log. Not required by `hubbado/log`, and
    # Rails is not a dependency of this gem — the constant is read lazily, and the only place
    # this handler is ever registered is an environment file, where Rails is loaded by
    # definition.
    class RailsLogger < LogHandler
      # Rails has no logger method below debug, so the gem's trace is written as one. A handler
      # passing it straight through raises NoMethodError on the first trace line it is handed.
      RAILS_SEVERITIES = { trace: :debug }.freeze

      # Assigned rather than built, so a spec can read what was written without Rails.
      attr_writer :rails_logger

      def rails_logger = @rails_logger ||= ::Rails.logger

      # A Rails log is read after the fact, and by machine as often as by a person, so the
      # stacktrace is written whatever the severity — where a terminal withholds it below error
      # to stay readable.
      def log(subject, severity, message, data = nil, stacktrace = nil)
        rails_severity = RAILS_SEVERITIES.fetch(severity.to_sym, severity)

        rails_logger.send(rails_severity, "#{subject}: #{message}")
        rails_logger.send(rails_severity, data.inspect) unless data.nil?
        rails_logger.send(rails_severity, stacktrace) unless stacktrace.nil?
      end
    end
  end
end
