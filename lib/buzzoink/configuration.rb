require 'fog'

module Buzzoink
  class Configuration

    # Sets the prefix of the process name.  It's 
    # a way to keep track of all buzzoink processes.
    # Don't change this unless you know what you're
    # doing.  Use "name=" instead if you want to just
    # set your process apart.
    #
    # @example
    #   Buzzoink.configure do | c | 
    #     c.name_prefix = "My favorite hive process"
    #   end
    #
    # @default Managed Buzzoink process
    #
    attr_writer :name_prefix
    def name_prefix
      @name_prefix ||= 'Managed Buzzoink process'
    end

    # Sets the process name.
    #
    # @example
    #   Buzzoinks.configure do | c | 
    #     c.name = "One off test"
    #   end
    #
    # @default Main EMR process
    #
    attr_writer :name
    def name
      @name ||= 'Main EMR process'
    end

    # Full name of the process
    def full_name *args
      suffix_options = args.extract_options!

      "#{name_prefix} : #{name}".tap do | str |
        unless suffix_options.blank?
          suffix = " " + suffix_options.map { | k, v | "#{k} => #{v}" }.join(", ")
          str << suffix
        end
      end
    end

    # Sets the a backstop datetime for all EMR
    # queries.  Set it to a time before which
    # you care nothing about.
    #
    # @example
    #   Buzzoink.configure do | c | 
    #     c.epoch = DateTime.today.ago(3.weeks)
    #   end
    #
    # @default One week ago
    #
    attr_writer :epoch
    def epoch
      @epoch ||= DateTime.now.ago(1.week)
      unless @epoch.respond_to?(:iso8601)
        @epoch = Time.parse(@epoch.to_s)
      end
      @epoch.iso8601
    end

    # Sets the max number of on demand slaves
    # for this job flow.
    # If there are spot instances included
    # in the deployment, their number will
    # double this setting
    #
    # For example, if you leave the default of 20
    # set, there will be 20 on demand instances, 
    # 40 spot instances and a master resulting
    # in 61 total machines.
    #
    attr_writer :max_instances
    def max_instances
      @max_instances ||= 20
    end

    attr_accessor :aws_access_key_id
    attr_accessor :aws_secret_access_key
    attr_accessor :key_name
    attr_accessor :key_path
    attr_accessor :s3_log_location

    def emr
      @emr ||= Fog::AWS::EMR.new(
        :aws_access_key_id => @aws_access_key_id,
        :aws_secret_access_key => @aws_secret_access_key  
      )
    end

    def full_emr_configuration
      instances = {
        :ec2_key_name => key_name,
        :instance_groups => instance_settings_config,
        :keep_job_flow_alive_when_no_steps => true,
        :termination_protected => false
      }

      config = {
        :ami_version => '2.0', # Latest
        :instances => instances,
      }
      config[:log_uri] = s3_log_location unless s3_log_location.nil?

      Buzzoink.convert_hash_keys(config)
    end

    # Gets one of the EMR preset configurations
    # for instance groups.  The presets are currently
    # test and production.  Test is a single machine, Production
    # is 60 machines.
    #
    # @example
    #   Buzzoink.configure do | c | 
    #     c.instance_settings = :production
    #   end
    #
    # @default :test
    attr_writer :instance_settings
    def instance_settings *args
      @instance_settings ||= :test
    end

    def instance_settings_config
      meth = "instance_settings_#{instance_settings.to_s}"
      self.send(meth)
    end

    def instance_settings_production
      instance_groups = []

      # Master
      instance_groups << {
        :instance_count => 1,
        :instance_role => 'MASTER',
        :instance_type => 'm1.small',
        :market => 'ON_DEMAND',
        :name => 'Master group'
      }

      # Core
      instance_groups << {
        :instance_count => max_instances,
        :instance_role => 'CORE',
        :instance_type => 'c1.medium',
        :market => 'ON_DEMAND',
        :name => 'Compute group'
      }

      # Task :: Spot instances
      instance_groups << {
        :instance_count => (max_instances * 2),
        :bid_price => '0.08',
        :instance_role => 'TASK',
        :instance_type => 'c1.medium',
        :market => 'SPOT',
        :name => 'Flex group'
      }

      instance_groups
    end

    def instance_settings_test
      instance_groups = []

      # Master
      instance_groups << {
        :instance_count => 1,
        :instance_role => 'MASTER',
        :instance_type => 'm1.small',
        :market => 'ON_DEMAND',
        :name => 'Master group'
      }

      # Core
      instance_groups << {
        :instance_count => 1,
        :instance_role => 'CORE',
        :instance_type => 'c1.medium',
        :market => 'ON_DEMAND',
        :name => 'Compute group'
      }

      instance_groups
    end
  end
end
