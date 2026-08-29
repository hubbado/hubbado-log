require_relative 'automated_init'

# Which concerns the operator is shown. The level says what kind of thing happened; a tag says
# which concern it belongs to, so a completion that is simply frequent can be filtered without
# being demoted. LOG_TAGS is an allow-list, following Eventide's log gem, so that an operator
# moving between the two codebases meets one vocabulary.
context "Tags" do
  # The configuration is the process's and every file in this suite shares it, so the operator's
  # list is put back however the block ends.
  def self.tagged(log_tags)
    configured = Log.config.tags
    Log.config.tags = log_tags

    yield
  ensure
    Log.config.tags = configured
  end

  # The level is not the subject here, so it is left where every scenario passes it.
  def self.shows?(log_tags, message_tags)
    tagged(log_tags) { Log::Display.shows?(:info, message_tags) }
  end

  # An allow-list, not a mute list: a message is shown when its own tags intersect the operator's.
  context 'The operator names no tags' do
    test 'An untagged message is displayed' do
      assert shows?('', [])
    end

    # The cost of adoption, and the reason a tag ships with the variable that names it.
    test 'A tagged message is not' do
      refute shows?('', [:http])
    end
  end

  context 'The operator names a tag' do
    test 'A message carrying it is displayed' do
      assert shows?('http', [:http])
    end

    test 'A message carrying it among others is displayed' do
      assert shows?('http', %i[cache http])
    end

    test 'A message carrying another is not' do
      refute shows?('http', [:cache])
    end

    test 'An untagged message is not' do
      refute shows?('http', [])
    end
  end

  context 'The operator asks for untagged messages' do
    test 'An untagged message is displayed' do
      assert shows?('_untagged', [])
    end

    test 'A tagged message is not' do
      refute shows?('_untagged', [:http])
    end
  end

  # Subtracts from the allow-list. It cannot mean "everything except this" — a message has to be
  # named by an include before an exclusion has anything to take it out of.
  context 'The operator excludes a tag' do
    test 'A message carrying only it is not displayed' do
      refute shows?('http,-data', [:data])
    end

    test 'A message carrying it alongside an included tag is not displayed' do
      refute shows?('http,-data', %i[http data])
    end

    test 'A message carrying the included tag alone is displayed' do
      assert shows?('http,-data', [:http])
    end
  end

  # Carried because Eventide has it, and an operator's string has to mean the same thing here.
  context 'The operator asks for every tag' do
    test 'A tagged message is displayed' do
      assert shows?('_all', [:http])
    end

    test 'An untagged message is displayed' do
      assert shows?('_all', [])
    end

    test 'An excluded message is too, because _all is answered first' do
      assert shows?('_all,-http', [:http])
    end
  end

  context 'A message marked as displayed regardless' do
    test 'Is displayed whatever the operator named' do
      assert shows?('http', [:*])
    end
  end

  # AND, not OR: both filters have to pass. A tag cannot raise a message above the level.
  context 'Composed with the level' do
    test 'A named tag below the level is not displayed' do
      configured = Log.config.level
      Log.config.level = :info

      refute(tagged('http') { Log::Display.shows?(:debug, [:http]) })
    ensure
      Log.config.level = configured
    end
  end

  # Eventide splits LOG_TAGS on commas and takes each entry exactly as written, so a space after
  # a comma becomes part of the name. Trimming it here would be kinder and would mean the same
  # string filtered differently in the two gems, which is the one thing sharing the variable
  # cannot survive. The README tells operators not to put spaces in the list.
  context 'A list written with spaces after the commas' do
    test 'Takes the space as part of the name, as Eventide does' do
      refute shows?('http, cache', [:cache])
    end

    test 'Leaves the first entry, which has no space, working' do
      assert shows?('http, cache', [:http])
    end
  end
end
