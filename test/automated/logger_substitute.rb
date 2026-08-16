require_relative 'automated_init'

# The stand-in a spec puts in place of a class's logger, so it can ask what the class said. It
# records rather than writes, so no handler is involved and neither the level nor the tag list
# decides what can be read back.
context "Logger substitute" do
  message = Log::Controls::Message.example

  context 'Severities' do
    logger = Log::Controls::Logger.example

    logger.info('first')
    logger.warn('second')

    test 'Answers for one that was written' do
      assert logger.logged?(:warn)
    end

    test 'Answers for one that was not' do
      refute logger.logged?(:error)
    end

    test 'Answers whether anything was written at all' do
      assert logger.logged?
    end
  end

  context 'A logger nothing was written to' do
    logger = Log::Controls::Logger.example

    test 'Answers that nothing was' do
      refute logger.logged?
    end
  end

  context 'More than one message' do
    logger = Log::Controls::Logger.example

    logger.info('first')
    logger.warn('second')
    logger.info('third')

    test 'Keeps them in order' do
      assert logger.messages.map { |written| written.fetch(:message) } == %w[first second third]
    end

    test 'Selects the ones written at one severity' do
      assert logger.messages(:info).map { |written| written.fetch(:message) } == %w[first third]
    end

    test 'Answers with nothing for a severity never written' do
      assert logger.messages(:error).empty?
    end
  end

  # The severity methods are generated, so a severity is the method that was called. #log names
  # it as an argument instead, and both have to answer the same question.
  context 'A severity named through #log' do
    logger = Log::Controls::Logger.example

    logger.log('warn', message)

    test 'Answers for it' do
      assert logger.logged?(:warn)
    end

    test 'Selects it' do
      assert logger.messages(:warn).length == 1
    end
  end

  context 'A message carrying an exception' do
    logger = Log::Controls::Logger.example
    exception = Log::Controls::Exception.example

    logger.error('the card did not finish', exception)

    test 'Keeps the exception it was handed' do
      assert logger.messages(:error).first.fetch(:data).equal?(exception)
    end
  end

  # It is assigned where a logger goes, so a class that stores it or checks it still works.
  context 'Standing in for a logger' do
    logger = Log::Controls::Logger.example

    test 'Is one' do
      assert logger.is_a?(Log::Logger)
    end
  end
end
