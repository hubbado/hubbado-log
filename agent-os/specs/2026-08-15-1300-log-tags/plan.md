# hubbado-log: tags, following Eventide's log gem

FlowFast card 6839114 · branch `logger-honours-tags`

## Context

`hubbado-log` filters by level and nothing else. Level therefore carries two jobs: *what kind
of thing happened* and *how much of it there is*. During card 6838093 that collision produced a
real mistake — a completion logged at `debug` because a line per card felt too frequent for
`info`, leaving the log louder about work that was declined than about work that was done.

The rule written to fix it forbids the demotion:

> Levels say what kind of thing happened; they are not a volume control. When a line feels too
> frequent for `info`, the question to ask is whether it is really a completion — not whether
> to demote it. A genuine completion that is simply frequent is a filtering problem, not a
> severity one.

That rule had no mechanism behind it. Tags are the missing axis.

Eventide's `evt-log` already solves this, and `hubbado_saas` already runs it with `LOG_TAGS`.
The instruction taken at shaping is exact compatibility with that prior art on the
operator-facing surface and the tagging idiom — no divergence. Internal signatures are ours.

## Wished-for spec

The deliverable is this spec passing. `test/automated/tags.rb`:

```ruby
require_relative 'automated_init'

# Which lines reach a handler, by concern. The level says what kind of thing happened; a tag
# says which concern it belongs to, so a frequent completion can be filtered without being
# demoted. LOG_TAGS is an allow-list, following Eventide's log gem, so that an operator moving
# between the two codebases meets one vocabulary.
context "Tags" do
  message = Log::Controls::Message.example

  def self.writes?(log_tags, message_tags)
    handler = Log::Controls::LogHandler.new
    configured = Log.config.tags

    Log.config.tags = log_tags
    Log::Logger.new(Log::Controls::Subject.example, handler).info(message, tags: message_tags)
    Log.config.tags = configured

    !handler.severity.nil?
  end

  # An allow-list, not a mute list: a line writes when its own tags intersect the operator's.
  context 'The operator names no tags' do
    test 'An untagged line reaches the handler' do
      assert writes?('', [])
    end

    # The cost of adoption, and the reason a tag ships with the env var that names it.
    test 'A tagged line reaches no handler' do
      refute writes?('', [:matching])
    end
  end

  context 'The operator names a tag' do
    test 'A line carrying it reaches the handler' do
      assert writes?('matching', [:matching])
    end

    test 'A line carrying it among others reaches the handler' do
      assert writes?('matching', [:attio, :matching])
    end

    test 'A line carrying another reaches no handler' do
      refute writes?('matching', [:attio])
    end

    test 'An untagged line reaches no handler' do
      refute writes?('matching', [])
    end
  end

  context 'The operator asks for untagged lines' do
    test 'An untagged line reaches the handler' do
      assert writes?('_untagged', [])
    end

    test 'A tagged line reaches no handler' do
      refute writes?('_untagged', [:matching])
    end
  end

  # Subtracts from the allow-list. It cannot mean "everything except this" — a line has to be
  # named by something before an exclusion has anything to take it out of.
  context 'The operator excludes a tag' do
    test 'A line carrying only it reaches no handler' do
      refute writes?('matching,-data', [:data])
    end

    test 'A line carrying it alongside an included tag reaches no handler' do
      refute writes?('matching,-data', [:matching, :data])
    end

    test 'A line carrying the included tag alone reaches the handler' do
      assert writes?('matching,-data', [:matching])
    end
  end

  # Carried because evt-log has it, and an operator's string has to mean the same thing here.
  context 'The operator asks for every tag' do
    test 'A tagged line reaches the handler' do
      assert writes?('_all', [:matching])
    end

    test 'An untagged line reaches the handler' do
      assert writes?('_all', [])
    end

    test 'An excluded line still reaches the handler, because _all is answered first' do
      assert writes?('_all,-matching', [:matching])
    end
  end

  context 'A line marked as written regardless' do
    test 'Reaches the handler whatever the operator named' do
      assert writes?('matching', [:*])
    end
  end

  # AND, not OR: both filters have to pass. A tag cannot raise a line above the level.
  context 'Composed with the level' do
    handler = Log::Controls::LogHandler.new
    configured = Log.config.tags

    Log.config.tags = 'matching'
    Log::Logger.new(Log::Controls::Subject.example, handler, level: :info).debug(message, tag: :matching)
    Log.config.tags = configured

    test 'A named tag below the level reaches no handler' do
      assert handler.severity.nil?
    end
  end

  context 'Naming tags at a call site' do
    handler = Log::Controls::LogHandler.new
    configured = Log.config.tags

    Log.config.tags = '_all'
    Log::Logger.new(Log::Controls::Subject.example, handler).info(message, tag: :handle, tags: [:message])
    Log.config.tags = configured

    test 'tag: and tags: are both carried to the handler' do
      assert handler.tags == [:handle, :message]
    end
  end

  # The component's own tag, declared once rather than repeated at every call site.
  context 'A Log subclass declaring its component' do
    handler = Log::Controls::LogHandler.new
    configured = Log.config.tags

    Log.config.tags = '_all'
    Log::Controls::TaggedLog.configure(receiver = Log::Controls::Subject::Tagged.new)
    receiver.logger.log_handlers = [handler]
    receiver.logger.info(message, tag: :handle)
    Log.config.tags = configured

    test 'Stamps its tag alongside the call site\'s' do
      assert handler.tags == [:attio, :handle]
    end
  end
end
```

Shape left open for TDD to settle:

- The last context needs two new controls (`Controls::TaggedLog`, `Controls::Subject::Tagged`)
  purely to exercise the class-declaration path. If those read as scaffolding rather than
  domain, the seam is wrong and `tag!` wants a simpler one. **[TDD-driven]**
- `handler.tags == [:attio, :handle]` locks the order — component first, call site second.
  Asserting order at all may be over-specifying. **[TDD-driven]**
- `Log.config.tags = ... / restore` repeats longhand in the last three contexts. It follows the
  existing idiom at `test/automated/level.rb:137-141`; extracting a helper is a refactor once
  green, not a design decision now.

## Tasks

### Task 1: Save spec documentation

This folder. Committed before any implementation.

### Task 2: Make `test/automated/tags.rb` pass — which lines reach a handler, by tag

RED first, on the filter contexts alone. Then:

- **`lib/hubbado/log/tags.rb`** (new) — the operator's list as a value object. `Tags.parse`
  takes the `LOG_TAGS` string, an array, or nil; splits `-name` into exclusions while keeping
  the raw list, since an exclusion-only list still counts as "the operator named tags".
  `#write?` copies `evt-log lib/log/filter.rb:19-45` branch for branch, including `_all`
  answered ahead of exclusion, and `#intersect?` copies `filter.rb:55-61`.
- **`lib/hubbado/log/configuration.rb`** — `tags` accessor beside `level`, defaulting to an
  empty `Tags`, accepting a string so `LOG_TAGS` needs no parsing at the call site.
- **`lib/hubbado/log/log.rb`** — `TAGS_VARIABLE = "LOG_TAGS"` beside `LEVEL_VARIABLE`, read
  once into `Configuration.new`, keeping "the one place the environment is read" true.
- **`lib/hubbado/log/logger.rb`** — `tags:` on the constructor (what this logger stamps);
  `tag:`/`tags:` keywords on `#log` and on every generated severity method; the two arrayed and
  concatenated at the boundary as `evt-log lib/log/log.rb:76-78` does; the filter consulted
  after the level, so AND is preserved and an unknown severity still raises first.

### Task 3: Make the call-site and component-declaration contexts pass

> **Removed before merge.** The component declaration was built as planned and then taken out:
> it shipped a hook with no implementer, and porting it had dropped the reason for its own
> shape. See "Tags are declared at the call site, and only there" in `shape.md`. The plan is
> left as it was written, because what it asked for is why the removal is worth recording.

- **`lib/hubbado/log/log.rb`** — `self.tag!(tags)` returning `tags`, and `Log.configure`
  building the `Logger` with `tags: tag!([])`.
- **`lib/hubbado/log/controls/`** — the two controls the spec needs.

### Task 4: Make the handler receive the tags

- **`lib/hubbado/log/log_handler.rb`** — `log(_subject, _severity, _msg, _data = nil,
  _stacktrace = nil, tags: [])`.
- **`lib/hubbado/log/controls/log_handler.rb`** — `attr_accessor :tags`, recorded like the rest.
- `Logger#log` passing `tags:` to each handler.

### Task 5: Document and release

- **README** — a `## Tags` section beside `## Level`: the syntax, the `hubbado_saas` string as
  the worked example, and both known limitations stated plainly.
- **ChangeLog** — `2.0.0`, Added and Changed, with the handler break called out.
- **gemspec** — `2.0.0`.

## Verification

- `./test.sh` — Test Bench, whole suite green, output pristine.
- `LOG_TAGS='matching' ./test.sh` and `LOG_TAGS='' ./test.sh` — the suite must not depend on the
  ambient variable, since `test/test_init.rb` already sets `LOG_LEVEL` and `LOG_TAGS` would
  become a second place the environment leaks into the run.
- Cross-check against the real gem: the probe table in `shape.md` re-run against
  `Hubbado::Log::Tags` must match `evt-log`'s `write_tag?` row for row.

## Out of scope

Adoption. No call site anywhere gains a tag in this card, and no application upgrades past
`1.2.0`. Card 6839170 covers `hubbado_core`; the other dependents are uncarded.
