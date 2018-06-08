module Hubbado
  module Log
    class LogHandler
      def log(_severity, _msg, _data = nil, _stacktrace = nil)
        raise NotImplementedError
      end
    end
  end
end
