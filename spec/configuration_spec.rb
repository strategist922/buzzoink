require 'spec_helper'

describe Buzzoink::Configuration do
  before(:each) do
    Buzzoink.clear_configuration
    @config = Buzzoink.configure do | c | 
      c.aws_access_key_id = 'username'
      c.aws_secret_access_key = 'password'
    end
  end

  it 'should clear the configuration' do
    Buzzoink.clear_configuration

    config = Buzzoink.configure
    config.aws_access_key_id.should be_nil
  end

  it 'should set the name' do
    @config.name = "Bob's one off"
    @config.name.should == "Bob's one off"
  end

  it 'should include any suffix arguments in the full name' do
    name = @config.full_name :arg1 => 'bob'
    name.should =~ /arg1 => bob$/
  end

  it 'should load active Fog instance' do
    @config.emr.class.should == Fog::AWS::EMR::Real
  end

  it 'should return the epoch in correct format' do
    d = Date.today.ago(3.weeks)
    @config.epoch = d
    @config.epoch.should == d.strftime("%Y-%m-%d")
  end

  it 'should get 3 instance groups on production settings' do
    @config.instance_settings = :production
    @config.instance_settings_config.size.should == 3
  end

  it 'should get 2 instance groups on default test settings' do
    @config.instance_settings.should == :test
    @config.instance_settings_config.size.should == 2
  end
end