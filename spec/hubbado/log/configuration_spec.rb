require 'spec_helper'

RSpec.describe Hubbado::Log::Configuration, type: :class do
  subject(:configuration) { described_class.new }

  describe '.loggers' do
    it 'is an empty array by default' do
      expect(configuration.loggers).to be_empty
    end

    it 'can add a logger' do
      configuration.loggers << Object
      expect(configuration.loggers).to match_array [Object]
    end

    it 'can be set to an array' do
      configuration.loggers = [Object]
      expect(configuration.loggers).to match_array [Object]
    end
  end
end
