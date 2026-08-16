# The configuration is the process's, not the class's

FlowFast card 6839172 · branch `configuration-belongs-to-the-process` ·
worktree `.worktrees/configuration-belongs-to-the-process`

## Context

`Hubbado::Log.inherited` gives every subclass its own `Dependency` module
(`lib/hubbado/log/log.rb:41-63`), so subclassing reads as supported. It is not: `@config` is a
class-level instance variable on `Hubbado::Log` (`log.rb:16`), and those are not inherited, so a
subclass answers `nil` from `config` and raises `undefined method 'loggers' for nil` on its first
line.

The ROI gate reframed the card. Its "worth deciding at the same time" question — delete the
subclass path instead — was rejected on evidence:

- **Deleting does not remove the defect.** Remove `inherited`'s subclass branch and a subclass
  still inherits `config`/`loggers` and still answers `nil`. It is not the smaller change it
  looks like.
- **The subclass path is `evt-log`'s, copied verbatim.** `inherited` + `self.inherited(self)` is
  `evt-log lib/log/log.rb:16-33` line for line, and Eventide subclasses `Log` across its gems
  (`evt-messaging lib/messaging/log.rb`). Deleting it diverges from the prior art this gem
  follows everywhere else.
- **The defect is ours, and it is the class-level configuration.** `evt-log` holds no
  configuration on the class at all — level, tags and device come from `Log::Defaults`, module
  methods reading `ENV` (`lib/log/defaults.rb`), stamped onto each instance at build time
  (`lib/log/log.rb:104-108`). Its one class-level ivar, `Registry#registry`, is `||=`-initialised
  and can never be nil. That is why `Messaging::Log < ::Log` just works.

So: hold the configuration where `evt-log` effectively holds it — once for the process — and the
subclass works for the same reason Eventide's does. The gem already talks this way:
`Logger#level` and `#tags` read `Log.config` directly (`lib/hubbado/log/logger.rb:17,21`), and two
spec files already call it "the configuration is the process's"
(`test/automated/tags.rb:10`, `test/automated/level.rb:133`).

## Deliverable

Two previously-failing specs now passing:

1. A subclass of `Hubbado::Log`, used as a dependency, writes a line — in
   `test/automated/dependency_module.rb`, where the `Dependency` behaviour already lives.
2. Reconfiguring builds the handlers again rather than answering a set built before it — in
   `test/automated/log.rb`, where `Log.configuration` is already exercised.

## The wished-for specs

`test/automated/dependency_module.rb`, added beside the existing `Dependency Module` context:

```ruby
context "Subclass" do
  Component = Class.new(Hubbado::Log)
  Receiver = Class.new { include Component::Dependency }

  Hubbado::Log.configuration do |config|
    config.loggers = [Log::Controls::LogHandler]
  end

  obj = Receiver.new
  obj.logger.info('some message')

  test "Writes" do
    assert Hubbado::Log.loggers.first.logged?(:info)
  end

  test "Through the handlers the process was configured with" do
    assert Component.loggers.equal?(Hubbado::Log.loggers)
  end
end
```

`test/automated/log.rb`:

```ruby
context 'Reconfiguring' do
  Hubbado::Log.configuration { |config| config.loggers = [Log::Controls::LogHandler] }
  built = Hubbado::Log.loggers.first

  Hubbado::Log.configuration { |config| config.loggers = [Log::Controls::LogHandler] }

  test 'Builds the handlers again' do
    refute Hubbado::Log.loggers.first.equal?(built)
  end
end
```

Assertion shapes, control choices and whether the identity check earns its place are
**[TDD-driven]** — the setup decides.

## The change

**`lib/hubbado/log/configuration.rb`** — the configuration becomes the process's, and carries the
handlers built from it:

- `Configuration.instance` — memoised on `Configuration`, which nothing subclasses, so it is one
  per process and can never answer `nil`. It reads `LOG_LEVEL` and `LOG_TAGS`, which is the ENV
  read moving here from `log.rb:16` with the comment that documents it.
- The built handler instances live with it, so `Log.loggers` on a subclass and on the root are the
  same objects, and one reconfiguration clears one memo. Name and mechanism **[TDD-driven]**; the
  receiving attribute is `Logger#log_handlers`, which is the word to reach for first. Watch the
  collision: `config.loggers` is the handler *classes* and is public API — it does not get renamed
  here.

**`lib/hubbado/log/log.rb`** — `config` and `loggers` delegate to it. `inherited`,
`self.inherited(self)`, `configuration`, `logger`, `log` and `configure` are untouched in
behaviour; `configuration` still forgets what was built after it yields, because a caller can
mutate `config.loggers` in place without going through the setter.

**`README.md`** — a short note that a subclass may be used as a dependency, so the next author
finds it documented rather than rediscovering it. Cut this if you would rather not advertise a
capability nothing uses yet.

**`ChangeLog.md` + `hubbado-log.gemspec`** — 1.4.1, `Fixed`. No public API changes.

## Order of work

1. Spec folder `agent-os/specs/{YYYY-MM-DD-HHMM-configuration-belongs-to-the-process}/`
   (`plan.md`, `shape.md`, `standards.md`, `references.md`), committed before any code.
2. RED: the subclass spec in `dependency_module.rb`. Confirm it raises
   `undefined method 'loggers' for nil`.
3. GREEN: `Configuration.instance`, `Log.config` delegating. Commit.
4. RED: the reconfiguring spec in `log.rb`. GREEN: the built handlers move onto the
   configuration. Commit.
5. README, ChangeLog, version bump. Commit.

Each commit leaves the suite green.

## Standards

From `metis-hermes-runtime/agent-os/standards/` (this gem has no standards folder of its own; the
prior spec `agent-os/specs/2026-08-15-1300-log-tags/` drew on the same ones):

- `global/conventions` — naming with no mechanism in the noun; the `Dependency` module idiom.
- `testing/test-writing` — behaviour-per-file scenario layout, Test Bench shapes.
- `testing/test-running` — `./test.sh`, and a single file with `ruby test/automated/<file>.rb`.
- `testing/controls` — `Controls::LogHandler` is the control the specs write through.

## References

- `evt-log-2.1.1.2` — `lib/log/log.rb:16-33` (the `inherited` shape this gem copied),
  `lib/log/defaults.rb` (configuration as process-wide module methods),
  `lib/log/log.rb:104-108` (`set_defaults` stamping level and tags per instance),
  `lib/log/registry.rb` (the one class-level ivar, `||=`-initialised).
- `evt-messaging-2.7.0.3/lib/messaging/log.rb` — a real `Log` subclass downstream.
- `agent-os/specs/2026-08-15-1300-log-tags/shape.md` — where this defect was found, and why the
  fix left with the `tag!` declaration.

## Verification

- `./test.sh` — 93 tests pass on the branch today; the two new specs join them.
- The card's reproduction, run in `bin/console`:

  ```ruby
  Component = Class.new(Hubbado::Log)
  Receiver = Class.new { include Component::Dependency }
  Receiver.new.logger.info('anything')   # writes, rather than raising
  ```
