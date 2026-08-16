module Hubbado
  class Log
    module Controls
      class LogHandler < Hubbado::Log::LogHandler
        # Everything a class logged, in order, because a run that reports two failures needs
        # both of them. The attributes below read the most recent.
        def messages
          @messages ||= []
        end

        # Replaces a class's logger with one writing here, keeping its subject. Neither the
        # configured level nor the configured tags decide what a spec attaching one of these can
        # read: it is asking what the class said, and the process's filters are not its subject.
        def self.attach(instance, level: :trace, tags: Tags::ALL)
          logger = instance.logger

          if logger.nil?
            raise ArgumentError, "#{instance.class} carries no logger to attach to. " \
                                 "Use .logger for a class that is handed one instead."
          end

          new.tap do |handler|
            instance.logger = Log::Logger.new(logger.subject, [handler], level: level, tags: tags)
          end
        end

        # For a class handed a logger rather than carrying one, and for a spec that wants both.
        def self.logger(subject = Subject.example, level: :trace, tags: Tags::ALL)
          handler = new

          [handler, Log::Logger.new(subject, [handler], level: level, tags: tags)]
        end

        def log(subject, severity, message, data = nil, stacktrace = nil)
          messages << {
            subject: subject,
            severity: severity,
            message: message,
            data: data,
            stacktrace: stacktrace
          }
        end

        # Named without a severity, this answers whether anything was written at all — which a
        # spec would otherwise have to infer from an attribute never having been set. A severity
        # is compared as a symbol, because #log takes a String as readily and passes on what it
        # was given.
        def logged?(severity = nil)
          return !messages.empty? if severity.nil?

          messages.any? { |written| written.fetch(:severity).to_s.to_sym == severity.to_s.to_sym }
        end

        def reset
          @messages = []
        end

        # The most recent message. Derived rather than assigned alongside `messages`, so the two
        # cannot disagree about which message is the latest.
        %i[subject severity message data stacktrace].each do |field|
          define_method(field) { messages.last&.fetch(field) }
        end
      end
    end
  end
end
