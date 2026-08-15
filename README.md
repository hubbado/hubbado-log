# Hubbado::Logger

This is an extremely lightweight, pluggable logging system

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hubbado-logger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hubbado-log

## Level

A message below the level reaches no handler.

```ruby
Hubbado::Log.configuration do |config|
  config.loggers = [MyStderrHandler]
  config.level = :debug
end
```

Without `config.level`, the level comes from the `LOG_LEVEL` environment variable:

    $ LOG_LEVEL=debug ./my-command

It defaults to `info`, so `debug` and `trace` are off until they are asked for.

Levels, lowest first:

| Level | What it records |
|---|---|
| `trace` | Most detailed tracing of program flow |
| `debug` | Completion of a secondary operation of a class or utility, or other details |
| `info` | Completion of the principal operation of a class or utility |
| `warn` | Unexpected state that is not an error, or is recoverable, and that a developer or operator should examine |
| `error` | Message logged just prior to raising an error |
| `fatal` | Message recorded, when possible, as the process is terminating due to an error |

A single logger can name its own with
`Hubbado::Log::Logger.new(subject, handlers, level: :debug)`.

`LOG_LEVEL` is shared with Eventide's log gem, which writes names this gem does not
know. A name that is not one of `debug`, `info`, `warn`, `error`, `fatal` or
`unknown` leaves the level at `info` rather than raising.

## Tags

A level says what kind of thing happened. A tag says which concern it belongs to, so a
completion that is simply frequent can be filtered out without being demoted to `debug`.

Name the concern where the message is written. `tag:` and `tags:` are both accepted, and a
message can use either or both:

```ruby
logger.info('Invoice raised', tags: [:invoicing, :billing])
logger.trace('Row read', tag: :data)
```

### `LOG_TAGS`

Which tagged messages are written is decided by `LOG_TAGS`, a comma-separated list:

    $ LOG_TAGS='_untagged,-data,billing,invoicing' ./my-command

| Entry | Meaning |
|---|---|
| `name` | Write messages carrying this tag |
| `-name` | Do not write messages carrying this tag, even if another entry includes them |
| `_untagged` | Write messages carrying no tag at all |
| `_all` | Write every message, whatever it carries |

A message can also tag itself `:*`, which writes it whatever the list says.

**Write the list with no spaces.** It is split on commas and nothing else, so `http, cache`
asks for a tag named `http` and another named `⎵cache`, which nothing carries. This is
Eventide's behaviour, kept deliberately so one `LOG_TAGS` means the same thing to both gems.

Tags compose with the level rather than replacing it: both filters have to pass, so a tag
cannot raise a message above the level and the level cannot rescue one the list leaves out.

A single logger can name its own list, as it can name its own level, so one component can be
read without turning up everything around it:

```ruby
Hubbado::Log::Logger.new(subject, handlers, level: :trace, tags: '_all')
```

The syntax and its behaviour are Eventide's log gem, copied deliberately so that a string an
operator writes means the same thing in both codebases. Two consequences of that are worth
knowing before adopting tags:

- **`LOG_TAGS` is an allow-list.** A tagged message is written only if the list names it. Adding
  a tag to a call site therefore *silences* that message everywhere `LOG_TAGS` has not been
  updated — cron, CI and production included. Ship the variable with the tag.
- **There is no way to mute one concern and keep the rest.** `-name` subtracts only from
  messages an include has already matched, and `_all` is answered before any exclusion, so
  `_all,-data` still writes `data` messages. Keeping everything except one concern means naming
  the others.

`LOG_TAGS` is shared with Eventide's log gem, as `LOG_LEVEL` is. In a process running both, one
list decides for both, and an application whose messages are all untagged goes silent unless the
list contains `_untagged`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hubbado/hubbado-logger.
