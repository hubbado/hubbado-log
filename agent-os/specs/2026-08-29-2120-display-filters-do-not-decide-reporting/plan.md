# LOG_TAGS and LOG_LEVEL filter what is printed, not what is reported

Card 6841819, board Software Dev (41409). Branch `log-tags-filters-what-is-printed`,
worktree `.worktrees/log-tags-filters-what-is-printed`. Baseline green: 137 tests, 0 failures.

## Context

`hubbado-log` applies both display filters inside `Logger#log`, **above** the handler fan-out:

```ruby
return if SEVERITIES.fetch(severity.to_sym) < SEVERITIES.fetch(level)   # logger.rb:30
return unless self.tags.write?(message_tags)                            # logger.rb:43
log_handlers.each { |handler| handler.log(...) }                        # logger.rb:51
```

So a setting an operator changes to control **what is printed** also decides **whether an
incident is reported** — `NotifyRollbar` sits behind the same two gates. Measured on
`hubbado-attio` with a forced crash: `LOG_TAGS=_all` prints the crash; `LOG_TAGS=scan` — an
operator narrowing to the step they are debugging — prints nothing and files no Rollbar item.

The fan-out is entirely Hubbado's addition. Upstream `evt-log` has no handlers at all
(`write.rb:17-19` is `device.write(message)` against a single IO), so the filters above it are an
inherited guard that only ever protected printing. Nobody re-sited them when a reporting handler
was slid underneath. This is a correction, not a divergence.

**Production SaaS is already armed, not just Metis.**
`infrastructure/kubernetes/hubbado/production/config-map.yaml:57` sets a *named* `LOG_TAGS` list,
and `hubbado_saas/hubbado_core/config/environments/production.rb:228-232` configures
`RailsLogger, NotifyRollbar` on `hubbado-log (1.5.0)`. Every `Hubbado::Log` warn and error in
`hubbado_core` is untagged today, so `_untagged` saves them — production is one tagged warn away
from a silently unreported incident.

The level is in scope for the same reason, agreed at the ROI gate. The card originally deferred it
on the argument that `NotifyRollbar`'s own `warn` floor protects it. It does not: `logger.rb:30`
returns before any handler is reached. And raising `LOG_LEVEL` to `warn` in production and staging
is a standing cost recommendation in the 2026 work log (~£40/mo, ~46 GiB) — `warn` is safe because
it is Rollbar's floor, and the next notch is not. Measured: nobody throttles Rollbar with
`LOG_LEVEL` today.

## Deliverable

A previously-failing spec that now passes: **a message reaches the reporting handler whatever
`LOG_TAGS` and `LOG_LEVEL` say, while the printing handlers still obey both.**

## The wished-for setup and call

The lines a client writes. The discriminator between the two handlers is the one thing left open.

```ruby
Log.configuration do |config|
  config.tags = "scan"
end

logger.error("cookies crashed", exception, tag: :cookies)

refute printing_handler.logged?     # LOG_TAGS=scan — nothing printed
assert reporting_handler.logged?    # the incident is filed anyway
```

`[TDD-driven]` What makes `reporting_handler` reporting — whether the display filter is a
collaborator the printing handlers hold, a predicate on `LogHandler` that `NotifyRollbar`
answers differently, or something the test setup argues for. **A mixin is not available without
your explicit yes** (`global/conventions` — "we do not write mixins; behaviour goes in a
collaborator"), which rules out the obvious `Filterable` shape.

`[TDD-driven]` The per-logger `tags:`/`level:` overrides (`logger.rb:17,21`). Measured: no
production call site sets either anywhere in the monorepo — only this gem's own controls
(`controls/log_handler.rb:23,31`). Specced, though: `test/automated/tags.rb`, "A logger naming its
own tags / Follows its own rather than the operator's". Carried, changed, retired, or made moot —
decided with the `evt-log` parity criterion, since upstream has the same seam.

## Files

**The move**
- `lib/hubbado/log/logger.rb` — both filters leave `#log`
- `lib/hubbado/log/stderr_logger.rb`, `lib/hubbado/log/rails_logger.rb` — gain the display filter
- `lib/hubbado/log/log_handler.rb` — base-class seam, if that is where it lands
- `lib/hubbado/log/notify_rollbar.rb` — expected untouched; it already self-selects `warn`+ at `:12,21-22`

**The specs**
- `test/automated/tags.rb`, `test/automated/level.rb` — both currently prove filtering at the
  Logger seam ("reaches the handler"); re-sited onto the printing handlers
- New behaviour: the reporting handler is reached whatever either filter says
- `lib/hubbado/log/controls/log_handler.rb` — `.attach`/`.logger` build a `Logger` with `level:`
  and `tags:` today; they will have to configure the handler instead

**Release**
- `hubbado-log.gemspec` — 1.6.0
- `ChangeLog.md`, `README.md` — README documents "both filters have to pass" at `:248-251` and the
  allow-list semantics at `:262-263`; both become false

**Rollout** (all in this card, per your call — twelve consumers, five repos)
- `hubbado_saas/hubbado_core` (`~> 1.5` → `~> 1.6`)
- `hubbado_saas/components/published_job_notification_component`
- `libraries/hubbado-trailblazer`, `libraries/turnstile`
- `metis-hermes-runtime` × 8 projects

The 1.0.1 consumers (`eco_core`, `hyerhub`, `hubbado-llm_conversation`, `hubbado-sequence`,
`dev_job_service`) are **excluded**: 1.0.1 has no tags at all and cannot have the defect.

## Ordered commits

1. Spec folder `agent-os/specs/2026-08-29-{HHMM}-display-filters-do-not-decide-what-is-reported/`
   (`plan.md`, `shape.md`, `standards.md`, `references.md`) — committed before any code.
2. RED → GREEN: the reporting handler is reached whatever `LOG_TAGS` says.
3. RED → GREEN: the same for `LOG_LEVEL`.
4. `tags.rb` and `level.rb` re-sited onto the printing handlers; `:*` still overrides.
5. `Controls::LogHandler.attach`/`.logger` follow the new seam.
6. README and ChangeLog.
7. Version 1.6.0, release.
8. One commit per consuming repo for the Gemfile bump, on its own branch and PR.

## Standards

Borrowed from `metis-hermes-runtime/agent-os/standards/`, as this repo's prior spec folders do —
`hubbado-log` has none of its own.

- `global/conventions` — the mixin rule (binds where a shared filter can live); naming; SRP
- `testing/test-writing` — behaviour-per-file layout for the re-sited specs
- `testing/controls` — control ownership, for `Controls::LogHandler`
- `testing/dependency-injection` — Substitutes, if the handler gains a driven seam

## Verification

- `./test.sh` in the worktree — 137 existing tests stay green, plus the new ones.
- End-to-end, the way the defect was measured: `hubbado-attio scan` forced to raise, against a
  **path-sourced** gem so it proves the fix before the release. Compare `LOG_TAGS=_all`,
  `LOG_TAGS=scan`, `LOG_TAGS=`, `LOG_TAGS=-cookies` — all four must file a Rollbar item; only the
  first prints. Repeat with `LOG_LEVEL=error` against a `warn`.
- Confirm one `LOG_TAGS` string still means the same thing in both gems for a *printed* line.

## Not in scope

- Per-severity tag lists — card 6841820 (Different tag lists at different log levels), explicitly after this one.
- The `Tags::EVERY_MESSAGE` marks on branch `pipeline-secrets-leave-the-hermes-agent-env-file`
  stay. Correct under any outcome, nothing to undo.
