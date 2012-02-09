require 'sys/proctable'
require 'active_support/core_ext'

require 'buzzoink/configuration'
require 'buzzoink/job'

module Buzzoink
  extend self

  def configure
    @configuration ||= Configuration.new
    if block_given?
      yield @configuration
    end
    @configuration
  end

  def emr
    configure.emr
  end

  def clear_configuration
    @configuration = nil
  end

  #
  # Candy so I can use underscore symbol keys
  #

  # Camel case an underscore symbol
  def camelcase_key(k)
    k.to_s.camelize
  end

  # Recursively set hash keys
  def convert_hash_keys(value)
    case value
      when Array
        value.map { |v| convert_hash_keys(v) }
      when Hash
        Hash[value.map { |k, v| [camelcase_key(k), convert_hash_keys(v)] }]
      else
        value
     end
  end

  class BuzzoinkError < StandardError
  end

  class DuplicateJobError < BuzzoinkError
  end

  class NoJobError < BuzzoinkError
  end

#  require 'sys/proctable'

# module Hive
#   EC2_KEY_NAME = 'oklbi-emr'
#   EPOCH = '2011-12-15'
#   KEY_PATH_NAME = 'vendor/emr_tools/oklbi-emr.pem'

#   module_function

#   def default_options
#     { 'Instances' => { 'InstanceCount' => 1,
#                        'MasterInstanceType' => 'm1.small',
#                        'SlaveInstanceType' => 'm1.small' },
#       'Name'      => default_name }
#   end

#   def immutable_options
#     { 'Instances' => { 'Ec2KeyName' => EC2_KEY_NAME,
#                        'KeepJobFlowAliveWhenNoSteps' => 'true', # Hive proxy must stay alive waiting for connections
#                        'TerminationProtected' => 'false' },
#       'LogUri' => 's3n://okl-bi/hive_logs' }
#   end

#   def all_default_options
#     recursive_merge(default_options, immutable_options)
#   end

#   def handle_options(options)
#     if options.has_key?('Instances')
#       self.immutable_options.each do |k,v|
#         raise "Hive Option #{k} is immutable!" if options['Instances'].has_key?(k) && options['Instances'][k] != v
#       end
#     end

#     recursive_merge(options, self.all_default_options)
#   end

#   def recursive_merge(h1, h2)
#     h1.merge(h2) do |k,v1,v2|
#       if v1.is_a?(Hash) && v2.is_a?(Hash)
#         recursive_merge(v1, v2)
#       else
#         v1 # Use default option unless override defined, or Hash to recurse
#       end
#     end
#   end

#   def ps(regex)
#     Sys::ProcTable.ps.select do |p|
#       p.cmdline =~ regex
#     end
#   end

#   def keepalive_ssh
#     Hive::Job.managed_jobs.each do |j|
#       j.tunnel
#     end
#   end

#   def describe_all_jobs
#     describe_job_flows('CreatedAfter' => EPOCH)
#   end

#   def terminate_all_jobs
#     jobs = Hive::Job.managed_jobs

#     if jobs.any? { |j| j.termination_protected? }
#       puts "Not terminating TerminationProtected jobs..."
#       jobs = jobs.select { |j| !j.termination_protected? }
#     end

#     if jobs.any?
#       ids = jobs.collect { |j| j.job_flow_id }
#       emr.terminate_job_flows('JobFlowIds' => ids)
#     end
#   end

#   def reset(options = {})
#     terminate_all_jobs
#     Hive::Tunnel.killall
#     Hive::Job.create(options)
#   end

#   def describe_job_flows(options)
#     emr.describe_job_flows(options).body['JobFlows']
#   end

#   def terminate_job(job_flow_id)
#     emr.terminate_job_flows('JobFlowIds' => [job_flow_id])
#   end

#   def run_hive(name, options)
#     hive_response = emr.run_hive(name, options)
#     hive_response.body['JobFlowId']
#   end

#   def emr
#     Fog::AWS::EMR.new
#   end
end
