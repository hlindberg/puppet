module Puppet::Fix
module Model

  # PlanBuilder is used to accumulate information about
  # * benchmarks
  # * issues
  # * reported_issues (i.e. an issue to fix for a set of nodes)
  #
  # The data must be built up such that known benchmarks are added
  # first. Issues can then be defined.
  # Thirdly, add all reported issues.
  #
  # The data model is then fully populated, and is ready for
  # query or for generation of a plan.
  # 
  # To make testing easier, the PlanBuilder is instantiated with
  # a fix provider - which is called to get fixes for reported
  # issues.
  #
  class PlanBuilder

    # A Set of issue objects - i.e. "names" of issues
    attr_reader :issues

    # Known Benchmarks Hash indexed by name.
    attr_reader :benchmarks

    # Issues that when reported should not be part of a generated plan
    #
    attr_reader :ignored_issues

    # The name of the remediation plan - default is "generated_plan"
    #
    attr_reader :plan_name

    DEFAULT_PLAN_NAME = 'generated_plan'.freeze

    # Creates a new PlanBuilder
    # Will use the given `fix_provider` to get fixes for issues that needs one
    #
    def initialize(fix_provider, plan_name = DEFAULT_PLAN_NAME)
      @fix_provider = fix_provider
      @issues = Set.new
      @benchmarks = {}
      @ignored_issues = Set.new
      @reported_issues = Hash.new {|hsh, key| hsh[key] = [] }
      @plan_name = plan_name
    end

    def add_issue_ref(issue_ref)
      add_issue(Issue.parse_issue(issue_ref))
    end

    # Adds an issue to the set of known (defined) issues.
    # It is ok to add issues for which there are are no reported issues
    # 
    def add_issue(issue)
      unless issue.is_a?(issue)
        raise ArgumentError, "Expected an Issue, got '#{issue.class}'"
      end
      unless @benchmarks[issue.mnemonic]
        raise ArgumentError, "Given issue references unknown benchmark '#{issue.mnemonic}'"
      end
      @issues.add(issue)
    end

    # Adds a known benchmark to the set
    #
    def add_benchmark(bmark)
      unless bmark.is_a? Benchmark
        raise ArgumentError, "add_benchmark requires a Benchmark, got '#{bmark.class}'."
      end

      # TODO: should be an warning/error to redefine it perhaps?
      @benchmarks[bmark.name] = bmark
    end

    def ignore_reported_issue(issue)
      unless issue.is_a?(Issue)
        raise ArgumentError, "ignore_reported_issue expects an Issue, got '#{issue.class}'"
      end
      @ignored_issues.add(issue)
    end

    def add_reported_issue(issue, *node_names)
      unless issue.is_a?(Issue)
        raise ArgumentError, "ignore_reported_issue expects an Issue, got '#{issue.class}'"
      end
      @reported_issues[issue] << ReportedIssue.new(issue, node_names)
    end

    def produce_plan
      # lines of text to be joined at the end
      result = []

      # Seen node sets
      node_sets = Set.new

      # Hash of Set[String] => index
      node_set_index = {}

      # Output header
      result << [
        '## Puppet Fix generated remediation plan',
        "## Created on <%= Time.now %>",
        '##'
      ]

      # Sort all reported issues
      sorted_reported = @reported_issues.sort_by {|ri| ri.issue.ref }

      # keep track of current bm, so new bm gets a new header
      prev_bm = nil

      # Output plan start
      result << [
        '',
        "plan #{plan_name}() {"
        ]

      # Iterate over all
      sorted_reported.each do |ri|
        # On new benchmark, output benchmark header
        if ri.issue.mnemonic != prev_bm
          prev_bm = ri.issue.mnemonic
          bm = @benchmarks[prev_bm]
          result << [
            "    ## Benchmark: #{bm.name}",
            "    ## Version  : #{bm.version}",
            "    ## Id       : #{bm.id}",
            ''
            ]
        end

        # Indicate if issue is skipped or being fixed
        if @ignored_issues[ri.issue]
          result << [
            "    ## Skip     : #{ri.issue.ref}"
            ]
        else
          result << [
            "    ## Fix      : #{ri.issue.ref}"
            ]


          # Find the fix
          # TODO: This version assumes that for a given bm/issue the fix is the same for all nodes
          #       This is a problem because fixes may depend on details about nodes (name, facts, etc).
          #       And this creates a problem because there is then the need to create subsets of nodes
          #       that share the very same fix.
          #       The FixProvider should have the knowledge how to best compute the set of fixes, get details
          #       about nodes etc.
          #
          # fixes is a hash of Set[String] => Fix
          #
          # TODO: find_fixes require benchmark facts
          fixes = fix_provider.find_fixes(ri.issue, ri.nodes)

          # TODO: check if any nodes from ri.nodes was left out of the returned sets.
          #       those must be reported as "no fix found" (or error since provider is wrong).
          #       Also, check for error of mapping one node to multiple fixes.
          #       Solution: call a method to get and validate result.
          #
          # Optimize target variables - reuse already defined targets variable
          fixes.keys.each_pair do |node_set, fix|
            idx = node_set_index[node_set]
            if idx.nil? && fix.requires_targets?
              # Variable was not already defined - generate it, and remember that it was
              idx = node_set_index.size
              node_set_index[ri.nodes] = idx
              result << [
                "    #{target_var(idx)} = [" + ri.nodes.sort.join(', ') + "]"
                ]
            end
            #   output code for the fix
            if fix.requires_targets?
              result << fix.to_pp(target_var(idx))
            else
              result << fix.to_pp()
            end
          end
        end
      end

      # Output plan end
      result << '}'
      result.join("\n")
    end

    # Returns the name to use for a target variable for node set index idx
    #
    def target_var(idx)
      "$target_#{idx}"
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
      @parameters = parameters
    end

    # Appends parameters to the array of parts
    #
    def format_with_params(*parts)
      unless parameters.empty?
        # TODO: v.inspect is a temporary crutch to get quoted strings 
        parts << parameters.map { |p, v| "'#{p}' => #{v.inspect}" }
      end
      parts << ')'
      [ parts.join(', ') ]
    end
  end

  class NamedFix < ParameterizedFix
    attr_reader :name

    def initialize(name, parameters={})
      super(parameters)
      @name = name
    end
  end

  class SyntheticFix < Fix
    def requires_targets?
      false
    end
  end

  class NoFix < SyntheticFix
    def to_pp()
      ['  ## Unavailable : No fix defined for this issue!']
    end
  end

  class SkippedFix < SyntheticFix
    def to_pp
      ['  ## Skip        : Configured to be skipped!']
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

  class Issue
    attr_reader :mnemonic
    attr_reader :section
    attr_reader :name
    attr_reader :ref # The issue ref string

    def initialize(mnemonic: nil, section: nil, name: nil)
      @mnemonic = mnemonic.freeze
      @section = section.freeze
      @name = name.freeze
    end

    def ref
      @ref ||= "#{@mnemonic}::#{@section}_#{@name}".freeze
    end

    # Can be used as key in a hash
    #
    def hash
      @hash ||= ref.hash
    end

    # Is equal to another issue
    # 
    def eql?(o)
      o.is_a?(Issue) && ref == o.ref
    end
    alias == eql?

    # Parses an issue string consisting of <mnemonic>::<section>[_.-]<name>
    # where:
    # * mnemonic is alphanumeric, starting with a letter, possibly a series of alphanumeric segments separated by ::
    # * section is a sequence of decimal digits separated by '.' or '_'
    # * name is any string until end of string after a separator of '_', '-' or '.'
    #
    # Returns an Issue with the corresponding attributes, or nil if part was missing.
    #
    def self.parse_issue(issue_string)
      return self.new unless issue_string.is_a?(String)

      regexp = /\A(?:(?<mnemonic>[A-Za-z][A-Za-z0-9_-]*(::[A-Za-z][A-Za-z0-9_-]*)?)::)?(?<section>[0-9](?:[._][0-9])*)?[._-]?(?<name>.+)?/
      matches = issue_string.match(regexp)
      captured = matches ? matches.named_captures : { }
      # Normalize the section
      unless captured['section'].nil?
        captured['section'].gsub!(/_/,'.')
      end
      self.new_from_hash(captured)
    end

    def self.new_from_hash(hash)
      unless hash.is_a?(Hash)
        raise ArgumentError, "Attempt to create an Issue from something that is not a hash. Got '#{hash.class}'."
      end
      self.new(mnemonic: hash['mnemonic'], section: hash['section'], name: hash['name'])
    end

  end

  class ReportedIssue
    attr_reader :issue # Reference to instance of Issue
    attr_reader :nodes # Set of node names (Strings)

    # Create an issue with or without nodes
    # @param nodes - none, one or more string node names
    #
    def initialize(issue, *nodes)
      raise ArgumentError, "issue parameter must be an Issue, got '#{issue.class}'." unless issue.is_a?(Issue)
      @issue = issue
      @nodes = Set.new
      self.add_nodes(nodes)
    end

    # Add more nodes to the same issue
    # @param nodes - none, one or more string node names
    def add_nodes(*nodes)
      @nodes.merge(nodes.flatten.map {|x| x.freeze })
      @nodes_cache = nil
    end

    # Returns a safe copy of nodes
    def nodes
      @nodes_cache ||= @nodes.dup.freeze
    end
  end

end
end
