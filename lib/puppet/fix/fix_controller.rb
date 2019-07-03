# The logic behind the Puppet::Application::Fix application (which deals only with UI and Puppet infrastructure setup)
# This controller implementation is thus easier to reuse someplace else (or rewrite in some other language)
#
class Puppet::Fix::FixController

  # Configuration read from file
  attr_reader :fix_config

  # The name of the plan that is generated
  attr_reader :plan_name

  attr_reader :fixdir

  def run(issue: nil, issues_file: nil, plan_name: nil, explain: false, fixdir: nil )

    # -- Validate given options
    #
    if issue && issues_file
      raise ArgumentError, "'issue' and 'issues_file' cannot be used at the same time"
    end

    if issue
      @reported_issues = [ {
        'issues'  => [issue.without_node],
        'nodes' => [ issue.node || 'example.com']
      }]
    elsif issues_file
      parse_issues_file(issues_file)
    else
      raise ArgumentError, "No issue was given, use 'issue' or 'issues_file'"
    end

    @explain = explain

    if fixdir.nil?
      @fixdir = Dir.pwd
    else
      @fixdir = fixdir
      unless File.directory?(fixdir)
        raise ArgumentError, "Given --fixdir #{fixdir} is not a directory or does not exist"
      end
    end

    # Configuration
    # -------------

    # -- Read config file for application
    @fix_config = load_config

    # -- The name of the plan that will be generated
    @plan_name  = plan_name || fix_config['default_plan_name'] || 'generated_plan'

    # -- Set up known_benchmarks
    #
    load_known_benchmarks

    # -- Create a fix provider
    #
    fix_provider = create_fix_provider

    # -- Create the PlanBuilder
    #
    plan_builder = Puppet::Fix::Model::PlanBuilder.new( fix_provider: fix_provider, plan_name: @plan_name)

    # -- Tell plan builder about available benchmarks
    #
    @benchmarks.each { |bm| plan_builder.add_benchmark(bm) }

    # -- Tell the plan builder about all reported issues
    #
    @reported_issues.each do | reported |
      reported['issues'].each do | issue |
        plan_builder.add_reported_issue(issue, *reported['nodes'])
      end
    end

    # -- Produce the plan on stdout
    #    TODO: write it to a given file
    #
    plan = plan_builder.produce_plan()
    puts plan

    return plan
  end

  private

  # Loads the known benchmarks.
  # Currently they are loaded from the config file
  # As a result, they are set in `@benchmarks`
  #
  def load_known_benchmarks
    # -- Set up known_benchmarks
    # CHEAT: loaded from the config
    # TODO: combine with information from modules
    #
    @benchmarks = (@fix_config['benchmarks'] || []).map {|b| Puppet::Fix::Model::Benchmark.from_hash(b) }
  end

  # Creates a Fix Provider that is later called to provide fixes for each reported issue
  # Returns an object responding to `find_fix(issue, facts)`
  #
  def create_fix_provider
    # -- Configure how fixes are found
    # CHEAT: This reads fixes from the config and creates a StaticFixProvider to service the Plan Builder
    # TODO: get fixes by looking up in hiera
    #
#    fixes = build_fixes(@fix_config['fixes'])
#    StaticFixProvider.new(fixes)

    Puppet::Fix::HieraFixProvider.new(env_dir: @fixdir, explain: @explain)
  end

  # Parses an issue string consisting of <mnemonic>::<section>[_.]<name>
  # where:
  # * mnemonic is alphanumeric, starting with a letter
  # * section is a sequence of decimal digits separated by '.' or '_'
  # * name is any string until end of string after a separator of '_' or '.'
  #
  # Returns  an Issue with the corresponding entries as string keys
  #
  def self.parse_issue(issue_string)
    Puppet::Fix::Model::Issue.parse_issue(issue_string)
  end

  def parse_issue(issue_string)
    self.class.parse_issue(issue_string)
  end

  # Parses the given file_name and validates its "issues on nodes" content
  #
  def parse_issues_file(file_name)
    loaded = YAML.load_file(file_name)
    @reported_issues = validate_and_normalize_issues_file(loaded, file_name)
  end

  # Loads the fix specific configuration from a file in current directory and returns a hash of
  # settings.
  #
  def load_config
    # TODO: This is obviously very simplistic, and the file should be named something else
    # TODO: There should be a way to reference a particular config as an option
    #
    begin
      return YAML.load_file(File.join(@fixdir, "fixconf.yaml"))
    rescue Errno::ENOENT => e
      # No config file - ignore
      # Return a default config - an empty hash
    end
    {}
  end

  # Validates issue_file type content coming from a given location (filename; is only for reporting/ reference).
  # This also normalizes constructs like node/nodes into nodes.
  #
  def validate_and_normalize_issues_file(data, source_location)
    # Top level is either a hash with keys 'nodes'/'node' and 'issue/issues', or an Array of such hashes
    #
    data = [data] unless data.is_a?(Array)
    unless data.all? {|x| x.is_a?(Hash) }
      raise "the 'issues_file' #{source_location} must be a hash or array of hashes, got a nested array"
    end
    data.each_with_index do | section, i |

      ## -- NODE / NODES
      #     Must have a node, or list of nodes

      node = section['node']
      nodes = section['nodes']
      if node && nodes
        raise "--issues_file #{source_location} at index #{i} uses both 'node' and 'nodes' - both not allowed at the same time."
      end
      if !(node || nodes)
        # Alternatively, allow this to end up reporting "no node had issue..."
        raise "--issues_file #{source_location} at index #{i} must contain either 'node' or 'nodes'"
      end

      if nodes
        if !nodes.is_a?(Array)
          raise "--issues_file #{source_location} at index #{i} has a 'nodes' entry that is not an array"
        end
      else
        # Normalize node to be nodes: [node]
        nodes = section['nodes'] = [node]
        section.delete('node')
      end

      # validate the node names
      # TODO: should probably strip them as well
      unless nodes.all? {|n| n.is_a?(String) && n =~ /[a-zA-Z0-9]/ }
        raise "--issues_file #{source_location} at index #{i} The node name '#{node}' is not acceptable as the name of a node"
      end

      ## -- ISSUE / ISSUES
      #     One of 'issue' or 'issues' normalized to 'issues' an array of issue reference strings

      the_issues = section['issues']
      the_issue = section['issue']
      if the_issue && the_issues
        raise "--issues_file #{source_location} at index #{i} uses both 'issue' and 'issues' - both not allowed at the same time."
      end
      if !(the_issue || the_issues)
        raise "--issues_file #{source_location} at index #{i} must contain either 'issue' or 'issues'"
      end

      if the_issues
        if !the_issues.is_a?(Array)
          raise "--issues_file #{source_location} at index #{i} has an 'issues' entry that is not an array"
        end
      else
        # Normalize 'issue' to be issues: [issue, ...]
        the_issues = section['issues'] = [the_issue]
        section.delete('issue')
      end

      section['issues'] = the_issues.each_with_index.map do |issue, ii|
        the_issue = parse_issue(issue)
        unless the_issue.section
          raise "--issues_file #{source_location} at index #{i}, issue[#{ii}] must contain 'section'"
        end

        unless the_issue.mnemonic
          raise "--issues_file #{source_location} at index #{i}, issue[#{ii}] must reference a benchmark."
        end
        # Map to the parsed and validated value
        the_issue
      end
    end
  end

  class StaticFixProvider
    def initialize(fixes_map)
      @fixmap = fixes_map
    end

    def find_fixes(issue: , nodes: , facts: {})
        { nodes => @fixmap[issue] || Puppet::Fix::Model::NoFix.new }
    end
  end

  # TODO: Refactor to use FixesBuilder instead of having this copy
  #
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
        mnemonic: fix_map['benchmark'] || @fix_config['default_benchmark'],
        section:  fix_map['section'],
        name:     fix_map['name']
        )

      fixes[the_issue] = fix
    end
    fixes
  end

end