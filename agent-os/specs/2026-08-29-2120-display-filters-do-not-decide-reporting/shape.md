# Display Filters Do Not Decide What Is Reported — Shaping Notes

Card 6841819. Shaped 2026-08-29.

## Scope

`Logger#log` applies both display filters above the handler fan-out, so `LOG_TAGS` and
`LOG_LEVEL` — settings an operator changes to control what is **printed** — also decide whether
`NotifyRollbar` files an **incident**. Move both filters below the fan-out: the printing handlers
obey them, the reporting handler never sees them.

In: the gem change, its specs, the 1.6.0 release, and the rollout to all twelve consumers that
have the defect.

Out: per-severity tag lists (card 6841820, explicitly after this one).

## Decisions

- **The level is in scope, decided at the ROI gate.** The card originally deferred it, arguing
  `NotifyRollbar`'s own `warn` floor protects it. That argument does not hold: `logger.rb:30`
  returns before any handler is reached, so a level above `warn` silences a warn-level incident
  exactly as a narrowed tag list does. It is the same conflation one notch further away — and it
  is a notch we are being walked toward, because raising `LOG_LEVEL` to `warn` in production and
  staging is a standing cost recommendation in the 2026 work log (~£40/mo, ~46 GiB). `warn` is
  safe, being Rollbar's floor. Above it is not.

- **Nobody throttles Rollbar with either control today.** Measured: `NotifyRollbar` is configured
  in `hubbado_core` production (`LOG_LEVEL: "info"`) and in the Metis pipelines (unset, so
  `info`). Rollbar rate-limits itself. So removing both from the reporting path costs nothing
  anyone relies on.

- **Released as 1.6.0.** A behaviour correction with no public API removed. Not 2.0.0: the changed
  meaning is only visible to a consumer that was relying on a display setting to suppress
  incidents, and none is.

- **Rollout lives in this card**, not in child cards — Señor Codigo's call. Twelve consumers
  across five repos, one branch and PR each.

- **The 1.0.1 consumers are excluded.** `hubbado-log 1.0.1` has no tags at all, so `eco_core`,
  `hyerhub`, `hubbado-llm_conversation`, `hubbado-sequence` and `dev_job_service` cannot have this
  defect. Upgrading them would be unrelated work; the original acceptance criterion demanded it
  and was amended at review.

- **The `Tags::EVERY_MESSAGE` marks in `metis-hermes-runtime` stay.** Branch
  `pipeline-secrets-leave-the-hermes-agent-env-file` marks fourteen crash and escalation lines
  with `:*`. That is upstream's own idiom and correct under any outcome here. It is not a fix for
  this card, because it fails open: a warn added later, or written in a gem that never heard of
  the convention, is one `LOG_TAGS` away from silence again.

- **No mixin without a specific yes.** `global/conventions` puts the burden of proof entirely on
  anyone proposing one, which rules out the obvious shared-`Filterable` shape for the two printing
  handlers. A collaborator, or the existing `LogHandler` superclass, or something the test setup
  argues for.

## Deferred to TDD

- **Where the display filter lands, and what distinguishes a printing handler from a reporting
  one.** Shape, not scope — a menu here would lock in a pre-formed answer. The wished-for setup
  and call below is the design tool.

- **The per-logger `tags:` and `level:` overrides** (`logger.rb:17,21`). Measured: no production
  call site sets either anywhere in the monorepo; the only setters are this gem's own controls
  (`controls/log_handler.rb:23,31`). It is specced, though — `test/automated/tags.rb`, "A logger
  naming its own tags / Follows its own rather than the operator's". Carried to the handler,
  changed, retired, or made moot by where the check lands. Decided together with the `evt-log`
  parity criterion, since upstream has the same per-logger seam and retiring it is a divergence.

## The wished-for setup and call

```ruby
Log.configuration do |config|
  config.tags = "scan"
end

logger.error("cookies crashed", exception, tag: :cookies)

refute printing_handler.logged?     # LOG_TAGS=scan — nothing printed
assert reporting_handler.logged?    # the incident is filed anyway
```

The friction to watch: what makes `reporting_handler` reporting. If that line reads awkwardly in
the setup, the production shape is wrong and it changes on text before any file is touched.

## Context

- **Visuals:** None. A gem with no interface.
- **References:** See `references.md`.
- **Product alignment:** N/A — `hubbado-log` has no `agent-os/product/`.

## Standards applied

Borrowed from `metis-hermes-runtime/agent-os/standards/`, as this repo's prior spec folders do.
`hubbado-log` has none of its own. See `standards.md`.

- `global/conventions` — the mixin rule binds where a shared filter can live; naming; SRP
- `testing/test-writing` — behaviour-per-file layout, and the rule for a behaviour that *moves*
- `testing/controls` — control ownership, for `Controls::LogHandler`
- `testing/dependency-injection` — Substitutes, if the handler gains a driven seam

## What the TDD settled

Recorded after the fact, because the two questions above were left open deliberately.

- **The discriminator is that a printing handler asks and a reporting one does not.** No flag, no
  predicate on the handler. `Display.shows?(severity, tags)` is a collaborator holding the whole
  decision, and `StderrLogger` and `RailsLogger` call it before writing. `NotifyRollbar` never
  does. `Logger` no longer filters at all — it fans out what it is given.

  An earlier attempt put a `LogHandler#displays?` predicate on the handler and kept the filtering
  in `Logger`. It worked and was smaller. The reason first written down here — that it could not
  give a handler the message's tags — does not survive scrutiny: the two are orthogonal, and
  `Logger` could have passed the tags *and* consulted `displays?`. The reasons that do hold:

  - **The failure direction is the loud one.** Forget the `Display.shows?` line in a printing
    handler and you over-print, which announces itself on the first run. Forget a `displays?`
    declaration under a filters-by-default predicate and you get silent under-reporting, which is
    the defect this card exists to remove.
  - **Rollout.** All twelve consumers already override `log`. Adding a line to a method they
    override is a smaller and more verifiable edit than restructuring each one.

- **The per-logger `level:` and `tags:` overrides are retired**, which is the AC4 answer. A handler
  reads the process configuration; a logger's own settings cannot reach it without putting the
  effective level and list back onto the contract as further arguments. Nothing across Hubbado set
  either override — only this gem's own controls did.

  This is the `evt-log` divergence AC6 was written to catch, and it is taken knowingly rather than
  discovered later. Upstream keeps the seam; upstream also has one destination and no fan-out, so
  it never has to choose.

- **The cost accepted:** a printing handler that forgets to ask `Display` prints everything. That
  is the same shape of defect as the `:*` convention this card criticises — a rule to remember at
  every call site — inverted to over-printing rather than under-reporting. Accepted with two
  printing handlers in the gem, zero custom handlers across Hubbado, and a spec on each. Called
  out in the README next to the handler example.

- **Released as 2.0.0, not 1.6.0.** Both the sixth argument and the retired overrides are
  breaking.
