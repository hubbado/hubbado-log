require_relative 'automated_init'

# Which messages reach a handler, by concern. The level says what kind of thing happened; a tag
# says which concern it belongs to, so a completion that is simply frequent can be filtered
# without being demoted. LOG_TAGS is an allow-list, following Eventide's log gem, so that an
# operator moving between the two codebases meets one vocabulary.
context "Tags" do
  message = Log::Controls::Message.example

  # The configuration is the process's and every file in this suite shares it, so the operator's
  # list is put back however the block ends. Without the ensure, one raising example would leave
  # the list mutated for every file that runs after it.
  def self.tagged(log_tags)
    configured = Log.config.tags
    Log.config.tags = log_tags

    yield
  ensure
    Log.config.tags = configured
  end

  # Built here rather than through the control's factory, which names its own list: this is the
  # spec for the operator's, so it has to be the one deciding.
  def self.writes?(log_tags, message_tags)
    written?(log_tags) { |logger| logger.info(Log::Controls::Message.example, tags: message_tags) }
  end

  # For a call site that names its tags some other way than the plural keyword.
  def self.written?(log_tags)
    handler = Log::Controls::LogHandler.new
    logger = Log::Logger.new(Log::Controls::Subject.example, handler, level: :trace)

    tagged(log_tags) { yield logger }

    handler.logged?
  end

  # An allow-list, not a mute list: a message writes when its own tags intersect the operator's.
  context 'The operator names no tags' do
    test 'An untagged message reaches the handler' do
      assert writes?('', [])
    end

    # The cost of adoption, and the reason a tag ships with the variable that names it.
    test 'A tagged message reaches no handler' do
      refute writes?('', [:http])
    end
  end

  context 'The operator names a tag' do
    test 'A message carrying it reaches the handler' do
      assert writes?('http', [:http])
    end

    test 'A message carrying it among others reaches the handler' do
      assert writes?('http', %i[cache http])
    end

    test 'A message carrying another reaches no handler' do
      refute writes?('http', [:cache])
    end

    test 'An untagged message reaches no handler' do
      refute writes?('http', [])
    end
  end

  context 'The operator asks for untagged messages' do
    test 'An untagged message reaches the handler' do
      assert writes?('_untagged', [])
    end

    test 'A tagged message reaches no handler' do
      refute writes?('_untagged', [:http])
    end
  end

  # Subtracts from the allow-list. It cannot mean "everything except this" — a message has to be
  # named by an include before an exclusion has anything to take it out of.
  context 'The operator excludes a tag' do
    test 'A message carrying only it reaches no handler' do
      refute writes?('http,-data', [:data])
    end

    test 'A message carrying it alongside an included tag reaches no handler' do
      refute writes?('http,-data', %i[http data])
    end

    test 'A message carrying the included tag alone reaches the handler' do
      assert writes?('http,-data', [:http])
    end
  end

  # Carried because Eventide has it, and an operator's string has to mean the same thing here.
  context 'The operator asks for every tag' do
    test 'A tagged message reaches the handler' do
      assert writes?('_all', [:http])
    end

    test 'An untagged message reaches the handler' do
      assert writes?('_all', [])
    end

    test 'An excluded message still reaches the handler, because _all is answered first' do
      assert writes?('_all,-http', [:http])
    end
  end

  context 'A message marked as written regardless' do
    test 'Reaches the handler whatever the operator named' do
      assert writes?('http', [:*])
    end
  end

  # AND, not OR: both filters have to pass. A tag cannot raise a message above the level.
  context 'Composed with the level' do
    handler, logger = Log::Controls::LogHandler.logger(level: :info)

    tagged('http') do
      logger.debug(message, tag: :http)
    end

    test 'A named tag below the level reaches no handler' do
      refute handler.logged?
    end
  end

  # The handler is given the tags rather than only the decision made from them, so that one can
  # Both keywords are accepted and both kept. Asserted through the filter, which is where tags
  # are observable: nothing downstream is given them, so a spec reading them back off a handler
  # would be reading its own double.
  context 'Naming tags at a call site' do
    test 'The singular names one' do
      assert(written?('request') { |logger| logger.info(message, tag: :request) })
    end

    test 'The plural names one' do
      assert(written?('response') { |logger| logger.info(message, tags: [:response]) })
    end

    test 'Given both, the singular is still kept' do
      assert(written?('request') do |logger|
        logger.info(message, tag: :request, tags: [:response])
      end)
    end

    test 'Given both, the plural is still kept' do
      assert(written?('response') do |logger|
        logger.info(message, tag: :request, tags: [:response])
      end)
    end
  end

  # The operator's list is symbols, because LOG_TAGS is parsed into them. A call site writing a
  # String would otherwise match nothing and its message would vanish — the one failure this
  # gem must never produce without saying so.
  context 'A tag named as a String' do
    test 'Is matched against the operator\'s list' do
      assert writes?('http', ['http'])
    end

    test 'Is matched whichever keyword names it' do
      assert(written?('cache') { |logger| logger.info(message, tag: 'cache') })
    end
  end

  # The same escape hatch the level has: one logger can be turned up without the process being
  # turned up around it. Eventide keeps tags per logger for this reason, and without it the only
  # way to read one component's messages is to mutate process-wide state and put it back.
  context 'A logger naming its own tags' do
    test 'Follows its own rather than the operator\'s' do
      handler = Log::Controls::LogHandler.new
      logger = Log::Logger.new(Log::Controls::Subject.example, handler, level: :trace, tags: '_all')

      tagged('http') { logger.info(message, tag: :cache) }

      assert handler.logged?
    end

    test 'Leaves a logger without its own following the operator\'s' do
      handler = Log::Controls::LogHandler.new
      logger = Log::Logger.new(Log::Controls::Subject.example, handler, level: :trace)

      tagged('http') { logger.info(message, tag: :cache) }

      refute handler.logged?
    end
  end

  # Eventide splits LOG_TAGS on commas and takes each entry exactly as written, so a space after
  # a comma becomes part of the name. Trimming it here would be kinder and would mean the same
  # string filtered differently in the two gems, which is the one thing sharing the variable
  # cannot survive. The README tells operators not to put spaces in the list.
  context 'A list written with spaces after the commas' do
    test 'Takes the space as part of the name, as Eventide does' do
      refute writes?('http, cache', [:cache])
    end

    test 'Leaves the first entry, which has no space, working' do
      assert writes?('http, cache', [:http])
    end
  end

  # A handler's arguments did not change, so one written against any earlier version still
  # takes what it is given. Tags decide whether it is called at all, and nothing more.
  context 'A handler written before tags existed' do
    unchanged = Class.new(Hubbado::Log::LogHandler) do
      attr_reader :seen

      def log(subject, severity, message, data = nil, stacktrace = nil)
        (@seen ||= []) << [subject, severity, message, data, stacktrace]
      end
    end.new

    tagged('http') do
      logger = Log::Logger.new(Log::Controls::Subject.example, unchanged, level: :trace)
      logger.info(message, tag: :http)
      logger.info(message, tag: :cache)
    end

    test 'Is given the message the list named' do
      assert unchanged.seen.length == 1
    end

    test 'With the arguments it has always taken' do
      assert unchanged.seen.first.length == 5
    end
  end
end
