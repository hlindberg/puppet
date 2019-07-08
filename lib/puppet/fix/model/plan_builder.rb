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
  def initialize(fix_provider: nil, plan_name: DEFAULT_PLAN_NAME)
    @fix_provider = fix_provider || NoFixProvider.new
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
    unless issue.is_a?(Issue)
      raise ArgumentError, "Expected an Issue, got '#{issue.class}'"
    end
    unless @benchmarks[issue.mnemonic]
      raise ArgumentError, "Given issue references unknown benchmark '#{issue.mnemonic}'"
    end
    @issues.add(issue)
    issue
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
    add_issue(issue)
    @ignored_issues.add(issue)
    issue
  end

  def add_reported_issue(issue, *node_names)
    unless issue.is_a?(Issue)
      raise ArgumentError, "ignore_reported_issue expects an Issue, got '#{issue.class}'"
    end
    add_issue(issue)
    @reported_issues[issue] << ReportedIssue.new(issue, node_names)
  end

  def combine_reported_issues
    @reported_issues.keys.each do |issue|
      ris = @reported_issues[issue]
      @reported_issues[issue] = [ ris.reduce(&:+)]
    end
  end

  def produce_plan
    # Combine individual reports so all nodes for one issue are processed together
    #
    combine_reported_issues

    # lines of text to be joined at the end
    result = []

    # Seen node sets
    node_sets = Set.new

    # Hash of Set[String] => index
    node_set_index = {}

    # Output header
    result << [
      '## Puppet Fix generated remediation plan',
      "## Created on #{Time.now}",
      '##'
    ]

    # Sort all reported issues
    sorted_reported = @reported_issues.sort_by {|key, value| key.ref }

    # keep track of current bm, so new bm gets a new header
    prev_bm = nil

    # Output plan start
    result << [
      '',
      "plan #{plan_name}() {"
      ]

    # Iterate over all
    first_benchmark = true
    sorted_reported.each do |the_issue, ri_array|
      ri_array.each do |ri|
        # On new benchmark, output benchmark header
        if ri.issue.mnemonic != prev_bm
          prev_bm = ri.issue.mnemonic
          bm = @benchmarks[prev_bm]
          if !first_benchmark
            result << ''
          else
            first_benchmark = false
          end
          result << [
            "    ## Benchmark: #{bm.name}",
            "    ## Version  : #{bm.version}",
            "    ## Id       : #{bm.id}",
            ]
        end

        # Indicate if issue is skipped or being fixed
        if @ignored_issues.include?(ri.issue)
          result << [
            "",
            "    # Ignored Issue : #{ri.issue.ref}",
            "    # Nodes         : #{ri.nodes.map {|n| n.inspect}.join(', ')}"
            ]
        else
          result << [
            "",
            "    # Issue      : #{ri.issue.ref}",
            "    # Nodes      : #{ri.nodes.map {|n| n.inspect}.join(', ')}"
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
          fixes = @fix_provider.find_fixes(issue: ri.issue, nodes: ri.nodes, facts: @benchmarks[prev_bm].all_facts)

          # TODO: check if any nodes from ri.nodes was left out of the returned sets.
          #       those must be reported as "no fix found" (or error since provider is wrong).
          #       Also, check for error of mapping one node to multiple fixes.
          #       Solution: call a method to get and validate result.
          #
          # Optimize target variables - reuse already defined targets variable
          fixes.each_pair do |node_set, fix|
            idx = node_set_index[node_set]
            if idx.nil? && fix.requires_targets?
              # Variable was not already defined - generate it, and remember that it was
              idx = node_set_index.size
              node_set_index[ri.nodes] = idx
              result << [
                "    #{target_var(idx)} = [" + ri.nodes.sort.map {|n| n.inspect}.join(', ') + "]"
                ]
            end
            #   output code for the fix
            if fix.requires_targets?
              result << indent(fix.to_pp(target_var(idx)))
            else
              result << indent(fix.to_pp())
            end
          end
        end
      end
    end

    # Output plan end
    result << '}' << ''
    result.join("\n")
  end

  def indent(txt_array)
    txt_array.map {|line| "  " + line }
  end

  # Returns the name to use for a target variable for node set index idx
  #
  def target_var(idx)
    "$targets_#{idx}"
  end
end
end; end
