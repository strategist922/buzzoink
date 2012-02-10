module Buzzoink
  # A representation of the job in Amazon's EMR system.  There are a few dynamic methods
  # created in this object. The are basically candy backed by another method in this class
  #
  # [start_hive] start(:type => :hive)
  # [start_pig] start(:type => :pig)
  # [find_or_start_hive] find_or_start(:type => :hive)
  # [find_or_start_pig] find_or_start(:type => :pig)
  #
  class Job
    attr_reader :job_flow_id
    attr_reader :body

    READY_STATES = ['RUNNING', 'WAITING']
    PENDING_STATES = ['STARTING', 'BOOTSTRAPPING']
    ACTIVE_STATES = READY_STATES + PENDING_STATES

    class << self
      # Gets an EMR job based on job flow ID
      # This is not limited to Buzzoink jobs
      #
      # @example
      #   Buzzoink::Job.get 'j-234324325'
      #
      #
      def get job_id
        begin
          job_flows = Buzzoink.emr.describe_job_flows('JobFlowIds' => [job_id]).body

          self.new(job_flows['JobFlows'].first)
        rescue Excon::Errors::Error => e
          raise Buzzoink::NoJobError if e.message =~ /Specified job flow ID not valid/
          raise e
        end
      end

      # Get all EMR jobs created after the epoch.  The EMR
      # jobs are instantiated as Buzzoink::Job objects
      # Not limited to Buzzoink jobs
      #
      # @example
      #   jobs = Buzzoink::Job.get_jobs
      #
      #
      def get_jobs
        jobs = []
        raw = Buzzoink.emr.describe_job_flows('CreatedAfter' => Buzzoink.configure.epoch).body
        raw['JobFlows'].each do | jf |
          jobs << self.new(jf)
        end
        jobs
      end

      # Gets all jobs managed by Buzzoink.  Pass
      # a :type to get only certain job types
      #
      # @example
      #   all_buzz_jobs = Buzzoink::Job.get_managed_jobs
      #   just_hive_jobs = Buzzoink::Job.get_managed_jobs :type => :hive
      #
      # @default all Buzzoink jobs
      def get_managed_jobs *args
        options = args.extract_options!
        jobs = get_jobs

        return jobs.select { | j | j.body['Name'] =~ /^#{Buzzoink.configure.name_prefix}/} if options.blank?

        full_name = Buzzoink.configure.full_name(options)
        jobs.select { | j | j.body['Name'] == full_name}
      end

      # Gets all active jobs managed by Buzzoink.  Pass
      # a :type to get only certain job types
      #
      # @example
      #   all_buzz_jobs = Buzzoink::Job.get_active_managed_jobs
      #   just_hive_jobs = Buzzoink::Job.get_active_managed_jobs :type => :hive
      #
      # @default all active Buzzoink jobs
      def get_active_managed_jobs *args
        options = args.extract_options!
        jobs = get_managed_jobs options

        jobs.select { | j | ACTIVE_STATES.include?(j.body['ExecutionStatusDetail']['State'])}
      end

      # If a job type is already running, return it.  Otherwise start
      # a new job of that type
      #
      # @example
      #   job = Buzzoink::Job.find_or_start :type => :hive
      #
      # @default :type => :pig
      def find_or_start *args
        options = args.extract_options!
        options.reverse_merge! :type => :pig

        jobs = get_active_managed_jobs :type => options[:type]
        return jobs.first unless jobs.blank?

        self.start options
      end

      # Kill all Buzzoink managed jobs
      #
      # @example
      #   Buzzoink::Job.kill_all
      #
      def kill_all
        jobs = get_managed_jobs
        return false if jobs.blank?

        ids = jobs.map(&:id)
        kill_jobs ids
      end

      # Kill jobs based on job flow ID.
      # This is not limited to Buzzoink jobs
      #
      # @example
      #   true_or_false = Buzzoink::Job.kill_jobs 'j-23432432', 'j-54654'
      #
      def kill_jobs job_flow_ids
        # In case a single ID is sent
        flows = []
        flows << job_flow_ids

        result = Buzzoink.emr.terminate_job_flows('JobFlowIds' => flows.flatten)
        !!result.body['RequestId']
      end

      # Starts a job flow in EMR.  This job flow
      # can either be streaming, hive or pig.
      #
      # @example
      #   Buzzoink::Job.start(:type => :hive)
      #
      # @default :type => :pig
      #
      def start *args
        options = args.extract_options!
        options.reverse_merge! :type => :pig

        active_jobs = get_active_managed_jobs :type => options[:type]
        raise Buzzoink::DuplicateJobError unless active_jobs.blank?

        conf = Buzzoink.configure
        job = Buzzoink.emr.run_job_flow(conf.full_name(:type => options[:type]), conf.full_emr_configuration)

        # Add appropriate step for interactive job
        if options[:type] == :hive
          Buzzoink.emr.add_job_flow_steps(job.body['JobFlowId'], {'Steps' => [hive_step]})
        elsif options[:type] == :pig
          Buzzoink.emr.add_job_flow_steps(job.body['JobFlowId'], {'Steps' => [pig_step]})
        else
          raise Buzzoink::Error, "Current type is invalid :: #{options[:type]}"
        end

        get job.body['JobFlowId']
      end

      # :nodoc:
      def hive_step
        {
          'Name' => 'Hive',
          'ActionOnFailure' => 'TERMINATE_JOB_FLOW',
          'HadoopJarStep' => {
            'Jar' => 's3://elasticmapreduce/libs/script-runner/script-runner.jar',
            'Args' => [
              's3://elasticmapreduce/libs/hive/hive-script',
              '--base-path', 's3://elasticmapreduce/libs/hive/',
              '--install-hive',
              '--hive-versions', '0.7.1.1'
            ]
          }
        }
      end

      # :nodoc:
      def pig_step
        {
          'Name' => 'Pig',
          'ActionOnFailure' => 'TERMINATE_JOB_FLOW',
          'HadoopJarStep' => {
            'Jar' => 's3://elasticmapreduce/libs/script-runner/script-runner.jar',
            'Args' => [
              's3://elasticmapreduce/libs/pig/pig-script',
              '--base-path',  's3://elasticmapreduce/libs/pig/',
              '--install-pig'
            ]
          }
        }
      end

      # Some helper methods are included for each type of 
      # job.
      #
      # @example
      #   j = Buzzoink::Job.start_hive
      #   j = Buzzoink::Job.find_or_start_pig
      #
      [:hive, :pig, :streaming].each do | type |
        self.class_eval <<-RUBY
          def start_#{type.to_s}
            start(:type => :#{type})
          end

          def find_or_start_#{type.to_s}
            find_or_start(:type => :#{type})
          end
        RUBY
      end
    end

    def initialize body
      @job_flow_id = body['JobFlowId']
      @body = body
    end
    alias_method :id, :job_flow_id
  
    # Kills the current job
    #
    # @example
    #   job.kill
    #
    #
    def kill
      self.class.kill_jobs self.id
    end

    # Pulls the latest description for this
    # job from EMR
    def refresh!
      new_job = self.class.get id
      @body = new_job.body
      self  
    end

    # The current boot state of the instance
    def state
      body['ExecutionStatusDetail']['State']
    end

    # Boolean for determining whether the instance
    # is ready for operation
    def ready?
      READY_STATES.include?(state)
    end

    def steps
      body['Steps']
    end

    # Address to use for connection
    def public_dns
      body['Instances']['MasterPublicDnsName']
    end

    # Is this instance protected from termination
    def termination_protected?
      body['Instances']['TerminationProtected'] == 'true'
    end

    # The type of job (e.g. Hive, Pig, etc)
    def type
      if body['Name'] =~ /type => (\w+)/
        return $1.to_sym
      end

      return nil
    end
  end
end