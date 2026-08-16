require 'subst_attr'

module Hubbado
  class Log
    module Controls
      module Logger
        # A logger a spec assigns in place of a class's own, and then asks what the class said.
        # Named here because the substitute is reached by building a mimic of Log::Logger, which
        # is machinery a spec should not have to name.
        def self.example
          SubstAttr::Substitute.build(Log::Logger)
        end
      end
    end
  end
end
