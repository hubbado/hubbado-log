module Hubbado
  class Log
    class Configuration
      attr_accessor :loggers

      def initialize
        @loggers = []
      end
    end
  end
end
