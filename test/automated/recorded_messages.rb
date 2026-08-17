require_relative 'automated_init'

# What a spec can read back about what a class logged. This is the control five projects are
# being told to delete their own copy for, so its surface is the deliverable rather than
# scaffolding, and it earns a spec of its own.
context "Recorded messages" do
  message = Log::Controls::Message.example

  context 'A handler attached to a class' do
    receiver = Log::Controls::Receiver.example

    handler = Log::Controls::LogHandler.attach(receiver)

    receiver.logger.info(message, tag: :http)

    # The point of attaching one: read what the class said, whatever the process was configured
    # to write. A configured level already could not decide it; nor can a configured tag list.
    test 'Shows a tagged message the operator did not ask for' do
      assert handler.logged?
    end

    test 'Keeps the subject the class had' do
      assert handler.subject == Log::Controls::Receiver.name
    end
  end

  context 'A handler attached to a class carrying no logger yet' do
    receiver = Log::Controls::Receiver.without_logger

    test 'Says so rather than failing on nil' do
      assert_raises(ArgumentError) do
        Log::Controls::LogHandler.attach(receiver)
      end
    end
  end

  context 'Severities' do
    handler, logger = Log::Controls::LogHandler.logger

    logger.warn(message)

    test 'Answers for one that was written' do
      assert handler.logged?(:warn)
    end

    test 'Answers for one that was not' do
      refute handler.logged?(:error)
    end

    # #log takes a String as readily as a symbol, and hands the handler what it was given.
    test 'Answers for one named as a String' do
      handler, logger = Log::Controls::LogHandler.logger

      logger.log('info', message)

      assert handler.logged?(:info)
    end
  end

  context 'More than one message' do
    handler, logger = Log::Controls::LogHandler.logger

    logger.info('first')
    logger.warn('second')

    test 'Keeps them in order' do
      assert handler.messages.map { |written| written.fetch(:message) } == %w[first second]
    end

    test 'Reads the most recent through the attributes' do
      assert handler.message == 'second'
    end
  end

  # The attributes are the most recent message, so a message that was filtered out must not
  # leave the previous one standing as though it were still the latest.
  context 'A message the filter left out' do
    handler = Log::Controls::LogHandler.new
    logger = Log::Logger.new(Log::Controls::Subject.example, handler, level: :trace, tags: 'http')

    logger.info('written', tag: :http)
    logger.info('filtered', tag: :cache)

    test 'Records only the written one' do
      assert handler.messages.length == 1
    end

    test 'Leaves the attributes on the written one' do
      assert handler.message == 'written'
    end
  end

  context 'A handler reused' do
    handler, logger = Log::Controls::LogHandler.logger

    logger.info('before')
    handler.reset
    logger.info('after')

    test 'Forgets what came before the reset' do
      assert handler.messages.map { |written| written.fetch(:message) } == %w[after]
    end

    test 'Forgets the attributes too' do
      assert handler.message == 'after'
    end
  end
end
