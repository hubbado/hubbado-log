require_relative 'automated_init'

# Which concerns the operator is shown. A tag says which concern a message belongs to, so one
# that is simply frequent can be filtered without being demoted. The list is Eventide's syntax,
# so an operator meets one vocabulary in both codebases.
context "Tags" do
  # The level is not the subject here, so it is left where everything passes it.
  def self.shows?(log_tags, message_tags)
    DisplaySettings.showing(tags: log_tags) { Log::Display.shows?(:info, message_tags) }
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

  # Subtracts from the allow-list rather than meaning "everything except": an include has to
  # match before an exclusion has anything to take out.
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
      refute(DisplaySettings.showing(level: :info, tags: 'http') do
        Log::Display.shows?(:debug, [:http])
      end)
    end
  end

  # Split on commas and nothing else, as Eventide does, so a space becomes part of the name.
  # Trimming would be kinder and would filter the same string differently in the two gems.
  context 'A list written with spaces after the commas' do
    test 'Takes the space as part of the name, as Eventide does' do
      refute shows?('http, cache', [:cache])
    end

    test 'Leaves the first entry, which has no space, working' do
      assert shows?('http, cache', [:http])
    end
  end
end
