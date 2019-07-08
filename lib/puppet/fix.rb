module Puppet
  # Config for Puppet Fix
  #
  # @api private
  module Fix
    module Model
      require 'puppet/fix/model/fixes'
      require 'puppet/fix/model/plan_builder'
      require 'puppet/fix/model/benchmark'
      require 'puppet/fix/model/issue'
      require 'puppet/fix/model/reported_issue'
    end
    require 'puppet/fix/fixes_builder'
    require 'puppet/fix/fix_controller'
    require 'puppet/fix/hiera_fix_provider'
  end
end
