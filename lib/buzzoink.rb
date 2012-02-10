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
end
