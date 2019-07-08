module Puppet::Fix
module Model

class Issue
  attr_reader :mnemonic
  attr_reader :section
  attr_reader :name
  attr_reader :ref # The issue ref string
  attr_reader :node

  def initialize(mnemonic: nil, node: nil, section: nil, name: nil)
    @mnemonic = mnemonic.freeze
    @section = section.freeze
    @name = name.freeze
    @node = node.freeze
  end

  def ref
    return @ref unless @ref.nil?
    name_part = @name.nil? ? "" : "_#{@name}"
    @ref = (node ?
        "#{@mnemonic}://#{node}/#{@section}#{name_part}"
      : "#{@mnemonic}:/#{@section}#{name_part}"
    ).freeze
  end

  def without_node
    return self unless node
    self.class.new(mnemonic: mnemonic, section: section, name: name)
  end

  # Can be used as key in a hash
  #
  def hash
    @hash ||= mnemonic.hash ^ section.hash ^ node.hash
  end

  # Is equal to another issue with same benchmark, node, and section
  # (The name is ignored to avoid having to state it everywhere)
  # TODO: possibly enforce that "no name" matches any name, but that names must match
  def eql?(o)
    o.is_a?(Issue) && mnemonic == o.mnemonic && section == o.section && node == o.node
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

    # must be a valid URI
    uri = URI.parse(issue_string)
    unless uri.hierarchical?
      raise "Issue string does not have the correct form (must be in the form of a hierarchical URI"
    end

    mnemonic = uri.scheme
    node = uri.hostname
    path = uri.path

    # extract the section and any name/text after section
    #
    regexp = /\A(?:[\/]*)(?<section>[0-9]+(?:[._-][0-9]+)*)?[._-]?(?<name>.+)?/

    #regexp = /\A(?:(?<mnemonic>[A-Za-z][A-Za-z0-9_-]*(::[A-Za-z][A-Za-z0-9_-]*)?)::)?(?<section>[0-9](?:[._][0-9])*)?[._-]?(?<name>.+)?/
    matches = path.match(regexp)
    captured = matches ? matches.named_captures : { }
    # Normalize the section
    unless captured['section'].nil?
      captured['section'].gsub!(/[_-]/,'.')
    end
    self.new_from_hash(captured.merge({ 'mnemonic' => mnemonic, 'node' => node}))
  end

  def self.new_from_hash(hash)
    unless hash.is_a?(Hash)
      raise ArgumentError, "Attempt to create an Issue from something that is not a hash. Got '#{hash.class}'."
    end
    self.new(mnemonic: hash['mnemonic'], section: hash['section'], name: hash['name'], node: hash['node'])
  end

end
end; end
