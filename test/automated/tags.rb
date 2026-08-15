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
    handler = Log::Controls::LogHandler.new
    logger = Log::Logger.new(Log::Controls::Subject.example, handler, level: :trace)

    tagged(log_tags) { logger.info(Log::Controls::Message.example, tags: message_tags) }

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
  # route on a concern rather than print it.
  context 'Naming tags at a call site' do
    handler, logger = Log::Controls::LogHandler.logger

    tagged('_all') do
      logger.info(message, tag: :request, tags: [:response])
    end

    # Compared against a list rather than asked `include?`: if the message were ever filtered
    # out, `tags` would be nil and `include?` would raise instead of failing. Both are carried;
    # the order they arrive in is not something to depend on.
    test 'Both the singular and the plural reach the handler' do
      assert handler.tags.to_a.sort == %i[request response]
    end
  end

  context 'A message naming no tags' do
    handler, logger = Log::Controls::LogHandler.logger

    logger.info(message)

    test 'Reaches the handler with none' do
      assert handler.tags == []
    end
  end

  # The operator's list is symbols, because LOG_TAGS is parsed into them. A call site writing a
  # String would otherwise match nothing and its message would vanish — the one failure this
  # gem must never produce without saying so.
  context 'A tag named as a String' do
    test 'Is matched against the operator\'s list' do
      assert writes?('http', ['http'])
    end

    test 'Reaches the handler as a symbol' do
      handler, logger = Log::Controls::LogHandler.logger

      tagged('_all') { logger.info(message, tags: ['http'], tag: 'cache') }

      assert handler.tags == %i[http cache]
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

  # Handlers run in turn over the same message. One that appends a tag of its own — the obvious
  # first use of being given them — must not change what the next handler receives.
  context 'More than one handler' do
    appending = Class.new(Hubbado::Log::LogHandler) do
      def log(_subject, _severity, _message, _data = nil, _stacktrace = nil, tags: [])
        tags << :appended_by_a_handler
      end
    end.new

    recording = Log::Controls::LogHandler.new

    tagged('_all') do
      Log::Logger.new(Log::Controls::Subject.example, [appending, recording], level: :trace)
        .info(message, tag: :http)
    end

    test 'The second is given what the message carried' do
      assert recording.tags == [:http]
    end
  end
end
