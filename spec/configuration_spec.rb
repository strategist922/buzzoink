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
    d = DateTime.now.ago(3.weeks)
    @config.epoch = d
    @config.epoch.should == d.iso8601
  end

  # I'm not sure why, but some versions of DateTime do not
  # have the correct method.  We'll have to cast to Time
  it 'should not use DateTime for iso8601 formatting' do
    d = DateTime.now.ago(1.hour)
    d.stub(:iso8601).and_raise NoMethodError
    d.stub(:respond_to?).with(:iso8601).and_return(false)

    t = Time.parse(d.to_s).iso8601
    @config.epoch = d
    @config.epoch.should == t
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