module Hubbado
  class Log
    module Controls
      class LogHandler < Hubbado::Log::LogHandler
        attr_accessor :subject
        attr_accessor :severity
        attr_accessor :message
        attr_accessor :data
        attr_accessor :stacktrace

        def log(subject, severity, message, data = nil, stacktrace = nil)
          self.subject = subject
          self.severity = severity
          self.message = message
          self.data = data
          self.stacktrace = stacktrace
        end
      end
    end
  end
end
