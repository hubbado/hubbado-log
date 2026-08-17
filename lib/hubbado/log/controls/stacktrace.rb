module Hubbado
  class Log
    module Controls
      # What the logger synthesises for a line carrying no exception: `Kernel.caller`, joined
      # by newlines. Recognisably a stack, and recognisably not any other string a spec asserts
      # on.
      module Stacktrace
        def self.example
          "lib/scanning.rb:14:in 'sweep'\nlib/cli.rb:3:in 'call'"
        end
      end
    end
  end
end
