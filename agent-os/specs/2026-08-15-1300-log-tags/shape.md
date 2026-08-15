# Tags — Shaping Notes

## Scope

A second filtering axis for `hubbado-log`: a log line can carry tags, and `LOG_TAGS` decides
which tagged lines are written. Following Eventide's `evt-log` exactly on the operator-facing
surface and the tagging idiom, because `hubbado_saas` already runs that gem and an operator
moving between the two codebases should meet one vocabulary.

The gem only. No call site anywhere gains a tag in this card.

## Decisions

### Composition is AND

A line writes only when the level filter and the tag filter both pass — `evt-log`'s
`write?(message_level, message_tags)` (`lib/log/log.rb:98`). A tag cannot raise a line above
the level, and the level cannot rescue a line the tags exclude.

### `LOG_TAGS` is an allow-list, carried verbatim

Probed against `evt-log-2.1.1.2`:

| `LOG_TAGS` | message tags | writes? |
|---|---|---|
| `""` | `[]` | true |
| `""` | `[:matching]` | **false** |
| `matching` | `[:matching]` | true |
| `matching` | `[]` | **false** |
| `matching` | `[:attio]` | false |
| `matching` | `[:attio, :matching]` | true |
| `_untagged` | `[]` | true |
| `_untagged` | `[:matching]` | false |
| `_all` | `[:matching]` | true |
| `_all,-matching` | `[:matching]` | **true** — `_all` is answered before exclusion |
| `matching` | `[:*]` | true |

The awkward parts are carried along with the rest, because a string an operator writes has to
mean the same thing in both codebases.

### Two known limitations, recorded rather than fixed

1. **A tagged line is silent unless `LOG_TAGS` names it.** The moment a call site gains a tag,
   that line disappears for every operator who has not listed it — cron, CI and production
   included. Adoption must ship the environment variable alongside the first tag.
2. **There is no mute knob.** `-name` only subtracts from lines an include has already matched;
   it cannot mean "everything except this", and `_all` beats it outright. The card's wish for
   "one concern at full detail without lowering the floor for everything else" is therefore
   **not** delivered here.

Both are how Eventide is operated in practice. `hubbado_saas` names its list explicitly
everywhere — k8s deployments, `test/interactive/start.sh`, `interactive_init.rb` — always
`_untagged,-data,messaging,entity_projection,entity_store,ignored`. `-data` there subtracts the
`pretty_inspect` dumps from lines carrying both `:data` and `:message`, which is what an
exclusion is genuinely for.

### `LOG_TAGS` is already set, and not by us

`hubbado_saas/hubbado_core` depends on `hubbado-log` *and* already exports `LOG_TAGS` for
`evt-log`. Once `hubbado-log` honours the same variable, every one of its lines — all untagged
today — is judged against a list written for another gem's tags. They survive only because each
string begins with `_untagged`; a string that omits it silences `hubbado-log` outright, with no
code change anywhere.

This is the `LOG_LEVEL` / `_min` hazard already documented in `lib/hubbado/log/configuration.rb`,
except that one degrades to a default and this one degrades to silence. Sharing the variable is
the whole point of the compatibility, so the gem does not defend against it: the README states
it, and card 6839170 owns auditing every deployment string before `hubbado_core` bumps.

### Tags are declared at the call site, and only there — for now

The card asked for a decision with a reason. `evt-log` has two mechanisms:

- **Per call site, for the concern** — `logger.info(msg, tags: [:handle, :message])`
  (`evt-log lib/log/log.rb:75`; real use at `evt-messaging lib/messaging/handle.rb:191`).
- **Per component, on a `Log` subclass** — `def tag!(tags) = tags << :messaging`
  (`evt-messaging lib/messaging/log.rb:3`, and seventeen sibling gems with the same shape).

Both were built first, then the second was removed before merge. The reason is worth recording,
because "evt-log has it" looked like sufficient justification and was not.

The per-component half shipped as a hook with **no implementer**. Nothing in the gem overrode
`tag!`, nothing downstream could — 2.0.0 was unreleased and adoption is a separate card — and
its base was a no-op whose return value the one call site discarded. Its only override in
existence was the one written to test it. A hook whose sole user is its own spec is not a
decision made, it is a decision deferred while looking like one.

Porting it also broke the thing that made its shape sensible. In `evt-log` the `Log` subclass
*is* the logger, and `tag!` is called per write on an array that already holds the call site's
tags, so appending to it is natural. Here `Hubbado::Log` is a factory and `Logger` is the
instance, so `tag!` was called once at build time on a fresh empty array — keeping a mutation
protocol while removing the reason for it, and leaving a trap where an author who returns their
tags rather than pushing them gets silence.

So: **per call site now; per component when a real component needs one**, designed against that
call site rather than guessed at. The `tag:`/`tags:` keywords, the `LOG_TAGS` filter and the
handler change all stand on their own and have users the moment anything adopts.

Removed with it: `Hubbado::Log` subclass support. A class-level instance variable is not
inherited, so a subclass reached a nil configuration and raised on its first line — a real
defect, found while building `tag!`, and the only thing that needed it. Fixing a bug nothing
hits, with no spec left to cover it, would be the same mistake in a different place. It wants
its own card.

### The handler takes tags as a keyword

`log(subject, severity, msg, data = nil, stacktrace = nil, tags: [])`. Self-describing beside
five positionals that are already two-thirds `nil`, and it makes this the last breaking addition
of its kind — a handler accepting `**` survives the next one.

`evt-log` gives no guidance here: it has no handler concept at all. Output goes straight to an
IO (`lib/log/write.rb:10-19`), and `Log::Telemetry::Sink` is a test-observation mechanism for a
single logger, not a destination for the process's logs. The fan-out to `config.loggers` is a
`hubbado-log` invention, so its signature is ours to choose.

Breaking either way — a handler defined with five positionals raises `ArgumentError` whether the
sixth argument arrives positionally or by keyword. The gem goes **2.0.0**.

### The filter lives on the configuration, not the logger

`Logger#tags` means *what this logger stamps on every line*. The operator's list is
`Log.config.tags`. Giving `Logger` both meanings under one name is the collision to avoid, and
it is why the filter is not a `Logger.new` keyword the way `level:` is.

### A word already in use

`agent-os/standards/global/conventions.md` describes the `Dependency` module as giving each
class "its own named logger (tagged with the class name)" — "tagged" there means the *subject*.
The subject is not a tag and does not participate in filtering. Worth watching in review and in
any later edit of that standard.

## What TDD settled

Three things were left open at shaping. All three turned out to be about the per-component
declaration, and all three were answered by removing it:

- **The controls to exercise it.** The sketch invented `Controls::TaggedLog` and
  `Controls::Subject::Tagged`; the built version was `Controls::Log`. Neither survives, because
  the thing they existed to exercise does not.
- **Whether tag order should be asserted.** Moot — with one source of tags there is no order to
  argue about.
- **`Hubbado::Log` could not be subclassed at all.** A class-level instance variable is not
  inherited, so the first subclass ever written reached a nil configuration and raised on its
  first line. A real defect, but `tag!` was the only thing that needed it fixed, so the fix left
  with it and wants its own card.

The lesson underneath all three: the per-component half was never really designed, and each of
these questions was a symptom of that rather than an independent problem. Building both
mechanisms because the prior art has both meant the harder one was never held up against a real
use, and the spec that "proved" it worked was proving a hook against its own test double.

One further thing the work turned up: the suite was reading `LOG_TAGS` from the developer's
shell. Under `LOG_TAGS=matching` it reported 22 failures against correct code. `test/test_init.rb`
now sets the variable rather than defaulting it.

## Controls the gem was missing

Asked whether Eventide's `evt-env_var` would help these tests, the answer was no — it pushes
`ENV`, and this gem reads the environment once at load, so a push changes nothing downstream;
and it declares `evt-log` as a runtime dependency, which is the last thing this gem should take
on. Its `push_values` shape was worth stealing though: the spec's set-run-restore had no
`ensure`, so one raising example would have left the operator's list mutated for every file
after it.

Looking for the same kind of gap elsewhere found two long-standing ones:

- **`Controls::LogHandler` kept only the last line.** Five downstream projects — hubbado-attio,
  the three candidate tools and teamxchange-scrape — had each hand-rolled a replacement with
  byte-identical `lines`, `log` and `logged?`. One of them says so in a comment. The gem's
  control now keeps every message and answers `logged?` with or without a severity, so "nothing
  was written" is asserted rather than inferred from an attribute never being set. The existing
  attributes still hold the most recent.

  The collection is `messages`, not `lines` as the copies have it. One call to the logger
  renders as several lines whenever it carries a stacktrace or an exception's `full_message`,
  and a handler is free to write more than once, so a line is the rendered output rather than
  the thing being recorded. The whole gem was moved onto that word at the same time. The cost
  is real — roughly 72 call sites across `projects/` rename when each deletes its copy — and
  2.0.0, already breaking, is the cheapest moment it will ever be.
- **Nothing built a `Logger`.** Seven `Logger.new` sites across three spec files, plus a local
  helper in `level.rb`, plus `.attach`/`.logger` invented independently downstream.

A third, `Controls::Log`, was built and then removed with the declaration it existed for.

Deliberately not added: a control for tag lists. In the filter spec the literal strings are the
subject — `_all,-matching` behaving differently from `matching,-data` is the behaviour under
test — so naming them behind `.example` would hide what is being verified.

## Context

- **Visuals:** None.
- **References:** See `references.md`.
- **Product alignment:** N/A — `hubbado-log` has no `agent-os/product/`; this folder seeds
  `agent-os/` in the repo.

## Standards Applied

- `global/conventions` (logging section) — the level table, the volume-control rule this card
  supplies the mechanism for, and the shared-`LOG_LEVEL` precedent that the shared-`LOG_TAGS`
  hazard mirrors.
- `testing/test-writing` — one file per behaviour, filename describing everything inside it,
  behavioural rather than class-shaped names.
- `testing/test-running` — how the suite is invoked.
- `testing/controls` — `.example` conventions for the two new controls.
