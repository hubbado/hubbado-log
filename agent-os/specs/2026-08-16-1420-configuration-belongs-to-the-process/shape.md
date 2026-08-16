# The configuration is the process's — Shaping Notes

## Scope

`Hubbado::Log` cannot be subclassed. `@config` is a class-level instance variable
(`lib/hubbado/log/log.rb:16`), those are not inherited, so a subclass answers `nil` from `config`
and raises `undefined method 'loggers' for nil` on its first line — while `inherited`
(`log.rb:41-63`) builds it a `Dependency` module, which says subclassing is supported.

The gem only. Nothing downstream gains a subclass in this card.

## Decisions

### The card's open question was answered against deleting

The card asked whether subclassing should exist at all, and offered deleting `inherited`'s
subclass path as the smaller change. Three findings say otherwise:

1. **Deleting does not remove the defect.** A subclass without a `Dependency` module still
   inherits `config` and `loggers`, still answers `nil`, and still raises on `Component.log`. To
   remove the defect by deletion you would have to make subclassing raise deliberately — more
   code than fixing it.
2. **The subclass path is not ours to judge in isolation.** `inherited` plus
   `self.inherited(self)` is `evt-log lib/log/log.rb:16-33` copied line for line, and Eventide
   subclasses `Log` across its gems — `Messaging::Log < ::Log`
   (`evt-messaging-2.7.0.3/lib/messaging/log.rb`) is the canonical one, with seventeen siblings.
   This gem follows `evt-log` on the operator-facing surface and the dependency idiom already.
3. **The defect is the class-level configuration, which is ours.** `evt-log` holds no
   configuration on the class. Level, tags and device are `Log::Defaults` module methods reading
   `ENV` (`lib/log/defaults.rb`), stamped onto each instance by `set_defaults`
   (`lib/log/log.rb:104-108`). Its only class-level instance variable is `Registry#registry`,
   which is `||=`-initialised and can never answer nil — and which is *meant* to be per-class,
   because a subclass keeps its own instances. Nothing there can go nil for a subclass, which is
   why Eventide's subclasses work without anyone having thought about it.

So the fix is the one the card's second bullet already described: hold the configuration once for
the process. The subclass then works for the same reason `Messaging::Log` does.

### The gem already says the configuration is the process's

`Logger#level` and `#tags` read `Log.config` — the root class, not the class that built the
logger (`lib/hubbado/log/logger.rb:17,21`). Two spec files say it in words:
"The configuration is process-wide and every file in this suite shares it"
(`test/automated/level.rb:133`), "The configuration is the process's"
(`test/automated/tags.rb:10`). Only the storage disagreed with the design.

### The built handlers move with it

`@loggers ||= config.loggers.map(&:new)` (`log.rb:26`) is a second class-level memo. Left where it
is, a subclass builds its own set of handler instances from the same configuration, and
`Log.configuration` clears only the root's. Handlers hold state — `Controls::LogHandler` collects
every message, and that is how the suite reads what a class said — so two sets is not a detail.
The memo belongs with the configuration, where one reconfiguration clears one thing.

Not renamed here: `config.loggers` is the handler *classes* and is public API that consumers set.
The instances have a name already in `Logger#log_handlers`, which is what they are assigned to.
The collision is pre-existing and this card does not deepen or resolve it.

### What is left to TDD

Per the plan-mode split, the shape of the holder is not locked here:

- Whether `Configuration.instance` or another name carries the process's configuration.
  **[TDD-driven]**
- What the built handlers are called on it, and whether `loggers=` clearing them makes the
  explicit reset in `Log.configuration` redundant. **[TDD-driven]**
- Whether the identity assertion (`Component.loggers.equal?(Hubbado::Log.loggers)`) earns its
  place beside the "writes without raising" one. **[TDD-driven]**

Locked: the configuration is read through one holder that nothing subclasses; `inherited` stays;
the subclass spec lives in `test/automated/dependency_module.rb`.

### The ENV read moves, and becomes lazy

`log.rb:16` reads `LOG_LEVEL` and `LOG_TAGS` at load, and the comment there — "The one place the
environment is read" — is the thing worth keeping. It moves to the holder, which means the read
happens at first use rather than at load. `test/test_init.rb` sets both variables before
requiring the gem, so the suite is unaffected either way.

## Context

- **Visuals:** None.
- **References:** `evt-log-2.1.1.2`, `evt-messaging-2.7.0.3`, and
  `agent-os/specs/2026-08-15-1300-log-tags/` — see `references.md`.
- **Product alignment:** N/A — library.

## Standards Applied

- `global/conventions` — the `Dependency` module idiom this gem provides, and naming with no
  mechanism in the noun.
- `testing/test-writing` — where a behaviour's spec lives; the subclass behaviour joins the
  `Dependency` module's file rather than getting one named after the fix.
- `testing/test-running` — `./test.sh` for the suite.
- `testing/controls` — `Controls::LogHandler` is what the new specs write through.

## History

Found while building tags (card 6839114). The fix existed briefly on that branch, holding the
per-component `tag!` declaration up, and left with it when the declaration was removed for having
no implementer — recorded in `agent-os/specs/2026-08-15-1300-log-tags/shape.md`. That branch was
squashed to a single commit, so there is no reverted implementation in the history to start from;
`evt-log` is the reference instead.
