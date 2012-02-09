require 'spec_helper'

describe Buzzoink::Job, :vcr do
  # around(:each) do | tst |
  #   VCR.use_cassette("jobs",
  #     &tst)
  # end

  before(:each) do
    @config = Buzzoink.configure do | c | 
      c.aws_access_key_id = 'AKIAJTRVHA3SHWHP6HSA'
      c.aws_secret_access_key = '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'
      c.epoch = Date.today.ago(1.day)
    end
    Buzzoink::Job.kill_all
  end

  describe 'starting and terminating a job' do
    before(:each) do
      Buzzoink::Job.kill_all
      @job = Buzzoink::Job.start(:type => :hive)
    end

    it 'should assign the ID of the job on creation' do
      @job.id.should =~ /^j\-/
    end

    it 'should be able to kill a single job' do
      @job.kill.should be_true
    end

    it 'should be able to kill all Buzzoink jobs' do
      Buzzoink::Job.kill_all.should be_true
    end

    it 'it should not start a second job' do
      lambda { Buzzoink::Job.start(:type => :hive) }.should raise_error Buzzoink::DuplicateJobError
    end
  end

  describe 'different job type' do
    it 'should be able to start jobs of a different type' do
      hive_job = Buzzoink::Job.start_hive
      lambda { Buzzoink::Job.start_pig }.should_not raise_error Buzzoink::DuplicateJobError
    end
    
    it 'should fail to start two jobs of the same kind' do
      pig_job = Buzzoink::Job.start_pig
      lambda { Buzzoink::Job.start_pig }.should raise_error Buzzoink::DuplicateJobError
    end

    it 'should find a job of the same type instead of creating it' do
      pig_job = Buzzoink::Job.start_pig
      next_job = Buzzoink::Job.find_or_start_pig
      pig_job.id.should == next_job.id
    end
  end

  it 'should have a method to start a hive job' do
    Buzzoink::Job.should_receive(:start).with(:type => :hive)

    Buzzoink::Job.start_hive
  end

  it 'should find all active buzzoink managed jobs' do
    Buzzoink::Job.start(:type => :hive)
    jobs = Buzzoink::Job.get_active_managed_jobs
    jobs.size.should == 1
  end

  it 'should fail if no job to get' do
    lambda { Buzzoink::Job.get('fake_job_id') }.should raise_error Buzzoink::NoJobError
  end

  it 'should pull and save job details on start' do
    job = Buzzoink::Job.start_hive
    job.body['JobFlowId'].should == job.id
    job.body.include?('ExecutionStatusDetail').should be_true
  end

  it 'should find all buzzoink managed jobs' do
    jobs = Buzzoink::Job.get_managed_jobs
    jobs.size.should == 30
  end

  it 'should be able to get the current job if one is running' do
    initial = Buzzoink::Job.start(:type => :hive)
    gotten = Buzzoink::Job.find_or_start(:type => :hive)
    gotten.id.should == initial.id
  end

  it 'should have a specialty method per type' do
    Buzzoink::Job.should_receive(:find_or_start).with(:type => :hive)
    Buzzoink::Job.find_or_start_hive
  end

  describe 'instance methods' do
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
end