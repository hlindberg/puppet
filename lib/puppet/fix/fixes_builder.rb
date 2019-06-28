class Puppet::Fix::FixesBuilder

  attr_reader :default_benchmark

  def initialize(default_benchmark)
    @default_benchmark = default_benchmark
  end

  def build_fixes(fixes_array)
    fixes = {}
    return if fixes_array.nil?
    fixes_array.each do | fix_map |
      the_fix     = fix_map['fix'] or raise ArgumentError.new("A fix must be one of 'task', 'plan', or 'command' - got neither.")

      fix =
      if the_fix['task']
        Puppet::Fix::Model::TaskFix.new(the_fix['task'], the_fix['parameters'])

      elsif the_fix['plan']
        Puppet::Fix::Model::PlanFix.new(the_fix['plan'], the_fix['parameters'])

      elsif the_fix['command']
        Puppet::Fix::Model::CommandFix.new(the_fix['command_string'], the_fix['parameters'])
      end

      if fix.nil?
        raise ArgumentError.new("A fix must be one of 'task', 'plan', or 'command' - got neither.")
      end

      the_issue   = Puppet::Fix::Model::Issue.new(
        mnemonic: fix_map['benchmark'] || default_benchmark,
        section:  fix_map['section'],
        name:     fix_map['name']
        )

      fixes[the_issue] = fix
    end
    fixes
  end

end