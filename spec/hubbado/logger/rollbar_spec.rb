require 'spec_helper'
require 'ffaker'
require 'hubbado/logger/rollbar'

RSpec.describe Hubbado::Logger::Rollbar do
  describe '#log' do
    let(:message) { FFaker::HipsterIpsum.sentence }
    let(:data) { FFaker::HipsterIpsum.sentence }

    it "does not notify rollbar for debug" do
      expect(::Rollbar).to_not receive(:debug).with(data, message)

      described_class.new.log(:debug, message, data)
    end

    it "does not notify rollbar for info" do
      expect(::Rollbar).to_not receive(:info).with(data, message)

      described_class.new.log(:info, message, data)
    end

    it "notifies rollbar for :warn" do
      expect(::Rollbar).to receive(:warn).with(data, message)

      described_class.new.log(:warn, message, data)
    end

    it "notifies rollbar for error" do
      expect(::Rollbar).to receive(:error).with(data, message)

      described_class.new.log(:error, message, data)
    end

    it "notifies rollbar for fatal as error" do
      expect(::Rollbar).to receive(:error).with(data, message)

      described_class.new.log(:fatal, message, data)
    end

    it "notifies rollbar for unknown as error" do
      expect(::Rollbar).to receive(:error).with(data, message)

      described_class.new.log(:unknown, message, data)
    end
  end
end
