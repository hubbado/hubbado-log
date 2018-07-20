require "hubbado/log/configuration"
require "hubbado/log/logger"
require "hubbado/log/log_handler"

module Hubbado
  module Log
    SEVERITIES = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4, unknown: 5 }.freeze
    STACKTRACE_SEVERITIES = %i[warn error fatal unknown].freeze

    @config = Configuration.new

    class << self
      attr_reader :config

      def configure
        yield @config
      end

      def loggers
        @loggers ||= config.loggers.map(&:new)
      end

      def logger
        @logger = Logger.new(loggers)
      end

      def log(*args)
        logger.log(*args)
      end
    end
  end
end
