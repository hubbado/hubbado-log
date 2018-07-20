require 'hubbado/logger'
require 'rollbar'

module Hubbado
  class Logger
    class Rollbar < LogHandler
      def log(severity, msg, data = nil, _stacktrace = nil)
        case severity
          when :warn
            ::Rollbar.warn(data, msg)
          when :error, :fatal, :unknown
            ::Rollbar.error(data, msg)
        end
      end
    end
  end
end
