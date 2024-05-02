module Hubbado
  module Log
    module Controls
      module Exception
        def self.example
          # This raise and rescue method seems necessary to ensure that the
          # exception has a stable stacktrace
          raise ArgumentError, "Some message"
        rescue ArgumentError => e
          e
        end
      end
    end
  end
end
