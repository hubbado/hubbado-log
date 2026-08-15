module Hubbado
  class Log
    class LogHandler
      def log(_subject, _severity, _msg, _data = nil, _stacktrace = nil)
        raise NotImplementedError
      end
    end
  end
end
