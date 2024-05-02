module Hubbado
  class Log
    module Controls
      class LogHandler < Hubbado::Log::LogHandler
        attr_accessor :severity
        attr_accessor :message
        attr_accessor :data
        attr_accessor :stacktrace

        def initialize
          self.severity = nil
          self.message = nil
          self.data = nil
          self.stacktrace = nil
        end

        def log(severity, message, data = nil, stacktrace = nil)
          self.severity = severity
          self.message = message
          self.data = data
          self.stacktrace = stacktrace
        end
      end
    end
  end
end
