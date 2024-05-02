module Hubbado
  class Log
    module Controls
      module Data
        def self.example
          {
            one: { sample: 1, random: 'DEADBEEF' },
            two: [1, 2, 3]
          }
        end
      end
    end
  end
end
