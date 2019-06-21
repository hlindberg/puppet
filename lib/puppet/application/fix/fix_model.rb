
module Puppet::Application::Fix::Model

  class PlanBuilder

    # A Set of issue objects - names of issues
    attr_reader :issues

    # Known Benchmarks Hash indexed by name.
    attr_reader :benchmarks

    # Creates a new PlanBuilder
    # Will use the given `fix_provider` to get fixes for issues to fix
    #
    def initialize(fix_provider)
      @issues = Set.new
      @fix_provider = fix_provider

      @benchmarks = {}
    end

    def add_issue_ref(issue_ref)
      add_issue(Issue.parse_issue(issue_ref))
    end

    def add_issue(issue)
      unless issue.is_a?(issue)
        raise ArgumentError, "Expected an Issue, got '#{issue.class}'"
      end
      @issues.add(issue)
    end

    # Adds a known benchmark to the set
    #
    def add_benchmark(bmark)
      unless bmark.is_a? Benchmark
        raise ArgumentError, "add_benchmark requries a Benchmark, got '#{bmark.class}'."
      end

      # TODO: should be an warning/error to redefine it perhaps?
      @benchmarks[bmark.name] = bmark
    end

    def add_reported_issue(issue, *node_names)
    end

  end

  class Benchmark
    attr_reader :name
    attr_reader :version
    attr_reader :family
    attr_reader :id
    attr_reader :facts

    def self.from_hash(h)
      self.new(h['id'], h['name'], h['version'], h['family'], h['facts'])
    end

    def initialize(id, name, version, family, facts)
      @id = id
      @name = name
      @version = version
      @family = family
      @facts = facts
    end

    def all_facts
      @all_facts || = (facts || { } )['benchmark'] = { 'id' => id, 'name' => name, 'version' => 'version'}
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
      @issue = issue
      @nodes = Set.new
      self.add_nodes(nodes)
    end

    # Add more nodes to the same issue
    # @param nodes - none, one or more string node names
    def add_nodes(nodes*)
      @nodes.merge(nodes.flatten.map {|x| x.freeze })
      @nodes_cache = nil
    end

    # Returns a safe copy of nodes
    def nodes
      @nodes_cache ||= @nodes.dup.freeze
    end
  end

  class Node
    attr_reader :name
    def initialize(name:)
      @name = name
    end
  end

  class Report
    attr_reader :issues # Hash of issue ref string to Issue
    attr_reader :nodes # Hash of node name to Node
    attr_reader :node_sets # Array of Set of node names
    def initialize
      @issues = {}
      @nodes = {}
      @node_sets = []
    end

    def add_node(n)
      @nodes[n.name] = n
    end

    def add_issue(issue)
      @issues[issue.ref] = issue
    end


    end
end