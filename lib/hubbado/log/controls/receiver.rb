module Hubbado
  class Log
    module Controls
      # A class that takes a logger, which is what the handler controls attach to.
      class Receiver
        include Log::Dependency

        def self.example = new

        # One that has the attribute but no logger behind it, for the guard that refuses to
        # attach to it. The Dependency module cannot produce this — it builds a logger on first
        # read — so the shape has to be written out.
        def self.without_logger
          Class.new { attr_accessor :logger }.new
        end
      end
    end
  end
end
