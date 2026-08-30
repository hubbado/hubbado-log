# The display settings a spec wants while it runs, put back however the block ends. A handler
# that prints asks Display, so a spec exercising one has to say what the operator asked for —
# and the configuration is the process's, shared by every file in the suite, so one that left a
# setting behind would decide what every file after it displays.
module DisplaySettings
  def self.showing(level: nil, tags: nil)
    configured_level = Log.config.level
    configured_tags = Log.config.tags

    Log.config.level = level || :trace
    Log.config.tags = tags || Log::Tags::ALL

    yield
  ensure
    Log.config.level = configured_level
    Log.config.tags = configured_tags
  end
end
