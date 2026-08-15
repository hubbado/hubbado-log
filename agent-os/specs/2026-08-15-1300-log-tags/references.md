# References for Tags

## Eventide's log gem — the prior art being copied

- **Location:** `evt-log-2.1.1.2` (installed gem; `hubbado_saas` vendors it under
  `*/gems/ruby/*/gems/evt-log-2.1.1.2`)
- **Relevance:** The whole operator-facing surface of this card is a copy of it. `hubbado_saas`
  runs both gems side by side and they already share `LOG_LEVEL`; `LOG_TAGS` becomes the second
  shared variable.

Key patterns, by file:

| File | What to take |
|---|---|
| `lib/log/defaults.rb:10-18` | `LOG_TAGS` parsing — comma split, `to_sym`, empty list when unset |
| `lib/log/tags.rb:18-35` | The include/exclude split: a leading `-` moves a name to `excluded_tags`, and the raw list is kept as well, so an exclusion-only list still counts as "the operator named tags" |
| `lib/log/filter.rb:19-45` | `write_tag?` — the branch order, and specifically that `_all` is answered *before* exclusion |
| `lib/log/filter.rb:55-61` | `tags_intersect?` — exclusion checked first, then a non-empty intersection with the includes required |
| `lib/log/log.rb:75-92` | `call` — `tag:` and `tags:` arrayed and concatenated at the boundary, then positional from there down |
| `lib/log/log.rb:98` | `write?` — level AND tag, the composition rule |
| `lib/log/level.rb:105-111` | Severity methods carrying `tag:`/`tags:` through to `call` |
| `lib/log/level.rb:10-21` | `_min` / `_max` resolving to the first and last registered level — `_min` is `fatal`, the *quietest* |

Deliberately **not** copied:

- `lib/log/write.rb` and `lib/log/format.rb` — `evt-log` writes to an IO itself. `hubbado-log`
  fans out to handlers instead, which is a shape `evt-log` has no counterpart for.
- `lib/log/telemetry.rb` — a test-observation sink for one logger, not a log destination. It is
  the only place `evt-log` hands tags to anything downstream, so it was considered as a
  precedent for the handler signature and then set aside.
- `lib/log/registry.rb` — `evt-log` memoises one logger per subject; `hubbado-log` builds a new
  one per receiver.

## `tag!` — the component-declaration idiom

Eighteen Eventide gems define the same three-line shape. The canonical one:

```ruby
# evt-messaging-2.7.0.3/lib/messaging/log.rb
module Messaging
  class Log < ::Log
    def tag!(tags)
      tags << :messaging
    end
  end
end
```

Others worth seeing for how the vocabulary is chosen — `evt-poll/lib/poll/log.rb` adds three at
once (`:poll`, `:library`, `:verbose`), and `evt-entity_cache` names its tag `:cache` rather
than after the gem.

Real call sites, showing the two kinds of tag together:

```ruby
# evt-messaging-2.7.0.3/lib/messaging/handle.rb:191-192
handler_logger.info(tags: [:handle, :message]) { "Handled message (Message class: #{message.class.name})" }
handler_logger.info(tags: [:data, :message]) { message.pretty_inspect }
```

`:message` is the subject, `:handle` and `:data` are the concerns — which is why an operator's
`-data` removes the `pretty_inspect` dumps without losing the handled-message lines.

## How `LOG_TAGS` is actually operated

- **Location:** `hubbado_saas`
- **Relevance:** Proof that the allow-list is enumerated explicitly wherever the gem runs, and
  the source of the worked example for the README.

The same string appears in every one of them:

```
_untagged,-data,messaging,entity_projection,entity_store,ignored
```

| Where | File |
|---|---|
| Production (k8s) | `components/company_connection_component/kustomize/base/deployment.yaml:54` |
| Interactive runs | `components/company_connection_component/test/interactive/start.sh:1` |
| Test init | `components/*/test/interactive/interactive_init.rb:2` |
| Consumers, dev | `hubbado_core/run-pty.json:9` — `_untagged,turbo_stream,-data,messaging` |

`hubbado_core/app/lib/utils/disable_console_logging.rb:14-34` saves, nils and restores
`LOG_TAGS` — which will affect both gems once `hubbado-log` reads it. Card 6839170 owns that.

## The existing level filter — the pattern this follows

- **Location:** this repo, `hubbado-log` 1.1.0 and 1.2.0
- **Relevance:** The level is the axis tags are being added beside, and it settled the questions
  this card would otherwise re-open.

| File | What to follow |
|---|---|
| `lib/hubbado/log/log.rb:11-15` | `LEVEL_VARIABLE` and the one place the environment is read |
| `lib/hubbado/log/configuration.rb:20-24` | A shared variable carrying another gem's vocabulary is survived, not refused |
| `lib/hubbado/log/logger.rb:16` | A logger built without one follows the configuration |
| `lib/hubbado/log/logger.rb:23-25` | The filter is applied *after* the severity is validated, so quietening a logger never turns a typo into silence |
| `test/automated/level.rb` | The shape of the spec being written beside it, including the process-wide-configuration-put-back idiom at lines 137-141 |
