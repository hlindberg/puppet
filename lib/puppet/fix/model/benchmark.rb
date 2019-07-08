module Puppet::Fix
module Model

class Benchmark
  attr_reader :name
  attr_reader :version
  attr_reader :family
  attr_reader :id
  attr_reader :facts

  def self.from_hash(h)
    self.new(id: h['id'], name: h['name'], version: h['version'], family: h['family'], facts: h['facts'])
  end

  def initialize(id: nil, name: nil, version: nil, family: nil, facts: nil)
    @id = id
    @name = name
    @version = version
    @family = family
    @facts = facts
  end

  # The facts configured for the benchmark plus the `benchmark` fact with benchmark meta information
  # (To allow FixProvider to return different fixes for different benchmarks)
  #
  def all_facts
    @all_facts ||= (facts || { } ).merge({'benchmark' => { 'id' => id, 'name' => name, 'version' => version, 'family' => family }})
  end
end
end; end