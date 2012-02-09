require 'spec_helper'

# This is separate because I didn't feel like messing around 
# redoing all of the VCR cassettes
describe 'Buzzoink::Job instance methods' do
  before(:each) do\
    @job = Buzzoink::Job.new(job_hash)
  end

  it 'should refresh be able to refresh itself' do
    Buzzoink::Job.should_receive(:get).with(@job.id).and_return(@job)
    @job.refresh!
  end

  it 'should report its state' do
    @job.state.should == 'WAITING'
  end

  it 'should report whether its ready' do
    @job.ready?.should be_true
  end

  it 'should report if its not ready' do
    new_hash = job_hash
    new_hash['ExecutionStatusDetail']['State'] = 'BOOTSTRAPPING'

    job = Buzzoink::Job.new(new_hash)
    job.ready?.should_not be_true
  end

  it 'should be able to report its DNS' do
    @job.public_dns.should == 'ec2-50-16-148-218.compute-1.amazonaws.com'
  end

  it 'should be able to report its termination status' do
    @job.termination_protected?.should be_false
  end
end