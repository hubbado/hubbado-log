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
      assert logger.messages == %w[first second third]
    end

    test 'Selects the ones written at one severity' do
      assert logger.messages(:info) == %w[first third]
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
      assert logger.messages(:warn) == [message]
    end
  end

  # #messages is what a class said; #logged is everything about what it said.
  context 'What was logged' do
    logger = Log::Controls::Logger.example
    exception = Log::Controls::Exception.example

    logger.error('the card did not finish', exception)

    test 'Carries the message' do
      assert logger.logged(:error).first.message == 'the card did not finish'
    end

    test 'Carries the severity' do
      assert logger.logged(:error).first.severity == :error
    end

    test 'Carries the exception it was handed' do
      assert logger.logged(:error).first.data.equal?(exception)
    end
  end

  # A run writes several lines, so a spec asking about one of them has to say which. Asking about
  # the message and the tags together is the point: they are one fact about one line, and asserted
  # apart they can both pass against two different lines.
  context 'Asking about a particular line' do
    def self.written
      logger = Log::Controls::Logger.example

      logger.info('rec_1 handed back to the queue', tags: %i[rescoring sweep])
      logger.warn('rec_2 could not requeue', tag: :skipped)
      logger.error('rec_3 refused', tags: :cookies)

      logger
    end

    context 'By its message' do
      test 'Named in full' do
        assert written.logged?(message: 'rec_2 could not requeue')
      end

      # A line names a record, so matching the whole of it means writing the id into the spec and
      # changing it whenever the wording moves. A pattern says which line without either.
      test 'Named as a pattern' do
        assert written.logged?(message: /could not requeue/)
      end

      test 'Named in part, which is not a match' do
        refute written.logged?(message: 'could not requeue')
      end

      test 'Named as something never written' do
        refute written.logged?(message: /never said/)
      end
    end

    # The logger keeps both keywords in one list, so a spec asserting the singular would otherwise
    # break when a call site was rewritten to the plural — a change with no behaviour in it.
    context 'By its tags' do
      test 'Named through the plural keyword' do
        assert written.logged?(tags: %i[rescoring sweep])
      end

      # One tag is named as itself, as a call site names it. A list is for a line carrying more
      # than one, above.
      test 'Named through the singular keyword' do
        assert written.logged?(tags: :skipped)
      end

      # `Logger#log` wraps whatever it is given in `Array()`, so the plural keyword takes a
      # lonely symbol too, and a line written that way reads back the same.
      test 'Written as a lonely symbol through the plural keyword' do
        assert written.logged?(tags: :cookies)
      end

      # A call site writes them in whatever order reads well, and that is not a difference.
      test 'Named in another order' do
        assert written.logged?(tags: %i[sweep rescoring])
      end

      test 'Named as a subset, which is not the line\'s tags' do
        refute written.logged?(tags: :rescoring)
      end

      test 'Named as tags no line carries' do
        refute written.logged?(tags: :searching)
      end
    end

    context 'By everything at once' do
      test 'Answers for the line that matches all of it' do
        assert written.logged?(:info, message: /handed back/, tags: %i[rescoring sweep])
      end

      # The point of asking together: each half is true of a line, but of different ones.
      test 'Does not answer for halves that match different lines' do
        refute written.logged?(message: /handed back/, tags: :skipped)
      end

      test 'Does not answer when the severity is another line\'s' do
        refute written.logged?(:warn, message: /handed back/)
      end
    end

    # #logged and #messages take the same criteria, so the three cannot disagree about which lines
    # are being talked about.
    context 'Reading the lines rather than asking about them' do
      test 'Selects them' do
        assert written.logged(tags: :skipped).length == 1
      end

      test 'Says what they said' do
        assert written.messages(message: /handed back/) == ['rec_1 handed back to the queue']
      end
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
