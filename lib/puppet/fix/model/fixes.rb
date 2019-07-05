module Puppet::Fix
module Model

  # Returns NoFix for all issues
  #
  class NoFixProvider
    def find_fix_for(issue, nodes)
      { NoFix.new => nodes }
    end
  end

  class Fix
    def requires_targets?
      true
    end
  end

  class ParameterizedFix < Fix
    attr_reader :parameters

    def initialize(parameters={})
      unless parameters.is_a?(Hash)
        raise ArgumentError, "The parameters of a Fix must be a hash, got #{parameters.class}"
      end

      @parameters = parameters
    end

    # Appends parameters to the array of parts
    #
    def format_with_params(*parts)
      unless parameters.empty?
        # TODO: v.inspect is a temporary crutch to get quoted strings 
        parts << parameters.map { |p, v| "'#{p}' => #{v.inspect}" }
      end
      [ parts.join(', ') + ")"]
    end
  end

  class NamedFix < ParameterizedFix
    attr_reader :name

    def initialize(name, parameters={})
      super(parameters)
      unless name.is_a?(String) && !name.empty?
        raise ArgumentError, "The name of a Fix must be a non empty string, got #{name.class}"
      end
      @name = name
    end
  end

  class InsteadOfFix < Fix
    def requires_targets?
      false
    end
  end

  class NoFix < InsteadOfFix
    def to_pp()
      ['  # NO FIX     : No fix defined for this issue!']
    end
  end

  class SkippedFix < InsteadOfFix
    def to_pp
      ['  # Skipped    : Configured to be skipped!']
    end
  end

  class PlanFix < NamedFix
    def to_pp(targets_var_name)
      format_with_params("  run_plan('#{name}'", targets_var_name)
    end
  end

  class TaskFix < NamedFix
    def to_pp(targets_var_name)
      format_with_params("  run_task('#{name}'", targets_var_name)
    end
  end

  class CommandFix < ParameterizedFix
    attr_reader :command_string

    def initialize(command_string, parameters = {})
      super(parameters)
      @command_string = command_string
    end

    def to_pp(targets_var_name)
      format_with_params("  run_command('#{command_string}'", targets_var_name)
    end
  end

end
end
