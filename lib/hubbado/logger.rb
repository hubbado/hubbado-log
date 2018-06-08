require "hubbado/logger/version"

module Hubbado
  class Logger
    SEVERITIES = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4, unknown: 5 }.freeze
    STACKTRACE_SEVERITIES = %i[warn error fatal unknown].freeze

    attr_accessor :log_handlers

    def initialize(log_handlers = [])
      self.log_handlers = Array(log_handlers)
    end

    def log(severity, msg, data = nil)
      unless SEVERITIES.keys.include? severity.to_sym
        raise ArgumentError, "Unknown serverity #{severity}"
      end

      stacktrace = if data&.is_a?(Exception)
                     data.full_message
                   elsif STACKTRACE_SEVERITIES.include?(severity)
                     format_stacktrace Kernel.caller
                   end

      log_handlers.each do |handler|
        handler.log(severity, msg, data, stacktrace)
      end
    end

    private

    def format_stacktrace(stacktrace)
      stacktrace.join("\n")
    end

    class LogHandler
      def log(_severity, _msg, _data = nil, _stacktrace = nil)
        raise NotImplementedError
      end
    end
  end
end
