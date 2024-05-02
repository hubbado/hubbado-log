module Hubbado
  class Log
    include Dependency

    SEVERITIES = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4, unknown: 5 }.freeze
    STACKTRACE_SEVERITIES = %i[warn error fatal unknown].freeze

    @config = Configuration.new

    class << self
      attr_reader :config

      def configuration
        yield @config

        @loggers = nil
      end

      def loggers
        @loggers ||= config.loggers.map(&:new)
      end

      def logger
        @logger = Logger.new('', loggers)
      end

      def log(*args)
        logger.log(*args)
      end
    end

    def self.inherited(cls)
      cls.class_exec do
        dependency_module = Module.new do
          define_singleton_method :included do |reciever_class|
            reciever_class.class_exec do
              ::Dependency::Attribute.define(self, :logger, cls)

              define_method :logger do
                @logger ||= cls.configure self
              end
            end
          end
        end

        const_set :Dependency, dependency_module
      end
    end

    inherited(self)

    def self.configure(receiver, attr_name: nil)
      attr_name ||= :logger
      instance = Logger.new(receiver.class.name, loggers)
      receiver.public_send("#{attr_name}=", instance)
      instance
    end
  end
end
