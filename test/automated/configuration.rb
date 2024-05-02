require_relative 'automated_init'

context "Configuation" do
  configuration = Configuration.new

  context 'loggers' do
    test 'Empty array by default' do
      assert configuration.loggers.empty?
    end

    test 'Add a logger' do
      # TODO: Use a control
      configuration.loggers << Object
      assert configuration.loggers == [Object]
    end

    test 'Set to an array' do
      # TODO: Use a control
      configuration.loggers = [Object]
      assert configuration.loggers == [Object]
    end
  end
end
