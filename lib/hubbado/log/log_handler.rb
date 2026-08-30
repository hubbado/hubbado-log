module Hubbado
  class Log
    class LogHandler
      # Whether this handler would use a synthesised stacktrace. Answered before one is made,
      # because Kernel.caller costs more than the rest of a log call put together. True here, so a
      # handler written before this existed is asked nothing and keeps what it always had.
      def traces?(_severity, _tags = nil) = true

      def log(_subject, _severity, _msg, _data = nil, _stacktrace = nil, _tags = nil)
        raise NotImplementedError
      end
    end
  end
end
