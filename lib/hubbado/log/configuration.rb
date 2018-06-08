module Hubbado
  module Log
    class Configuration
      attr_accessor :loggers

      def initialize
        @loggers = []
      end
    end
  end
end
