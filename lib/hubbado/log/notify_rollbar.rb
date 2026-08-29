require 'rollbar'

require_relative '../log'

module Hubbado
  class Log
    # Forwards a log line worth an incident to Rollbar.
    class NotifyRollbar < LogHandler
      # Rollbar's own levels. It has none above error, so the two severities above `warn` share
      # it, and anything below a warning is running commentary that reaches the handlers which
      # print rather than this one.
      LEVELS = { warn: :warn, error: :error, fatal: :error, unknown: :error }.freeze

      def initialize(notifier: nil)
        super()

        @notifier = notifier
      end

      def log(subject, severity, message, data = nil, stacktrace = nil, _tags = [])
        level = LEVELS[severity.to_sym]
        return if level.nil?

        error = data if data.is_a?(::Exception)

        notifier.public_send(
          level, *[error, title(message), extra(subject, data, stacktrace)].compact
        )
      end

      private

      # Read rather than stored, so a process that reconfigures Rollbar after the log system
      # built its handlers is notified through what it configured.
      def notifier = @notifier || ::Rollbar

      # Rollbar matches its title by type: a message that is not a String is ignored, and the
      # item arrives with no title at all rather than with a bad one.
      def title(message) = message.to_s

      # One hash, never two. Rollbar scans its arguments by type and keeps the last hash it
      # finds, discarding any earlier one — so a line's own data and the fields added here have
      # to arrive merged, or one of them silently never reaches the item.
      #
      # Built fresh every call for the same reason it is merged: Rollbar deletes a key from the
      # hash it is given, and the caller still holds theirs.
      #
      # The handler's fields merge last. A call site names the record it is about, and an item
      # that could be told its subject was something else would file under a class that never
      # logged it.
      def extra(subject, data, stacktrace)
        extra = context(data).merge("subject" => subject)

        return extra if stacktrace.nil? || data.is_a?(Exception)

        extra.merge("stacktrace" => stacktrace)
      end

      # Rollbar matches a String to the message and an Exception to the exception, and ignores
      # anything else it is handed. Data that is neither is named here rather than dropped.
      def context(data)
        case data
          when nil, Exception then {}
          when Hash then data.transform_keys(&:to_s)
          else { "data" => data.inspect }
        end
      end
    end
  end
end
