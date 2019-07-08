module Puppet::Fix
module Model

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

  def +(other)
    raise "ReportedIssue can only add another ReportedIssue - got value of class #{other.class}" unless other.is_a?(ReportedIssue)
    raise "ReportedIssue can only combine nodes for same issue - got #{issue.ref} and {other.issue.ref}" unless other.is_a?(ReportedIssue)
    self.class.new(issue, nodes + other.nodes)
  end

  # Returns a safe copy of nodes
  def nodes
    @nodes_cache ||= @nodes.dup.freeze
  end
end
end; end
