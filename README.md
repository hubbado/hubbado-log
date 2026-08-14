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

A line below the level reaches no handler.

```ruby
Hubbado::Log.configuration do |config|
  config.loggers = [MyStderrHandler]
  config.level = :debug
end
```

Without `config.level`, the level comes from the `LOG_LEVEL` environment variable:

    $ LOG_LEVEL=debug ./my-command

It defaults to `info`, so `debug` is off until it is asked for. A single logger can
name its own with `Hubbado::Log::Logger.new(subject, handlers, level: :debug)`.

`LOG_LEVEL` is shared with Eventide's log gem, which writes names this gem does not
know. A name that is not one of `debug`, `info`, `warn`, `error`, `fatal` or
`unknown` leaves the level at `info` rather than raising.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hubbado/hubbado-logger.
