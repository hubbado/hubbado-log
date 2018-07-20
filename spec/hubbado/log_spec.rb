require 'spec_helper'
require 'hubbado/log/fake_log_handler'

RSpec.describe Hubbado::Log do
  it 'can log to configured loggers' do
    Hubbado::Log.configure do |config|
      config.loggers = [Hubbado::Log::FakeLogHandler]
    end

    Hubbado::Log.log(:info, 'test')

    expect(Hubbado::Log.loggers.first).to have_attributes(
      severity: :info,
      message: 'test',
      data: nil,
      stacktrace: nil
    )
  end
end
