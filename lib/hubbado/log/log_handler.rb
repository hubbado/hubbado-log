module Hubbado
  class Log
    class LogHandler
      # Tags arrive by keyword rather than as a sixth positional: they are self-describing
      # beside two arguments that are usually nil, and a handler taking `**` survives the next
      # thing a message learns to carry.
      def log(_subject, _severity, _msg, _data = nil, _stacktrace = nil, tags: [])
        raise NotImplementedError
      end
    end
  end
end
