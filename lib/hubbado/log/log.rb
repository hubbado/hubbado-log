module Hubbado
  class Log
    include Dependency

    # Ordered, because the level compares against them. `trace` is program flow, a message per
    # iteration; `debug` is the completion of a secondary operation, or a detail worth keeping;
    # `info` is the completion of the principal operation of a class or utility.
    SEVERITIES = { trace: 0, debug: 1, info: 2, warn: 3, error: 4, fatal: 5, unknown: 6 }.freeze
    STACKTRACE_SEVERITIES = %i[warn error fatal unknown].freeze

    LEVEL_VARIABLE = "LOG_LEVEL".freeze
    TAGS_VARIABLE = "LOG_TAGS".freeze

    class << self
      # Held by the configuration itself rather than here, because a class-level instance
      # variable is not inherited: a subclass asking this class would answer nil.
      def config = Configuration.instance

      def configuration(&block)
        config.change(&block)
      end

      def loggers = config.log_handlers

      def logger
        @logger = Logger.new('', loggers)
      end

      # The keywords are named rather than swept up with the positionals: a method taking only
      # `*args` accepts no keywords, so Ruby would fold them into a trailing hash and they would
      # arrive as the message's data — which a handler hands to Rollbar as the exception.
      def log(*args, tag: nil, tags: nil)
        logger.log(*args, tag: tag, tags: tags)
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
