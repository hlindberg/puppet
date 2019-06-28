# A fix provdider finding fixes based on information in hiera
#
class Puppet::Fix::HieraFixProvider
  # The directory acting as the environment
  # The `modulepath` is hardwired to be `modules` in this directory.
  #
  attr_reader :env_dir
  attr_reader :explain

  def initialize(env_dir:, explain: false)
    @env_dir = env_dir
    @explain = explain
  end

  # This first implementation will be horrible as it will create the env, modulepath, load and parse everything for every
  # issue. The API would need to change so the fix provider is aware of the benchmark - as it now defines the set of facts.
  # If we need to have facts per individual node, then we need to not only switch per benchmark, but per issue/node.
  # 
  # @param issue [Issue] - the issue to get a fix for
  # @param nodes [Set<String>] - the nodes to get the fix for
  # @param facts [Hash] - the facts to use
  # 
  def find_fixes(issue: , nodes: , facts: {})
    result = Puppet::Pal.in_environment('fixenv', env_dir: env_dir, modulepath: [], facts: facts, variables: {'zappa' => 'frank' }) do | pal |
      pal.with_script_compiler do |c|

        # cheat to get topscope
        scope = c.send(:internal_compiler).topscope

        # explain options - want to see explain for now to be able to figure out what is going on.
        # explain = true
        explain_data = true      # only has effect if explain is true
        explain_options = false  # only has effect if explain is true
        only_explain_options = explain_options && !explain_data

        lookup_invocation = Puppet::Pops::Lookup::Invocation.new(scope, {}, {}, explain ? Puppet::Pops::Lookup::Explainer.new(explain_options, only_explain_options) : nil)
        result = Puppet::Pops::Lookup.lookup(['fix::fixes'], nil, [], true, nil, lookup_invocation)
        puts lookup_invocation.explainer.explain if explain

        # result is Array[Struct[issue => issue_ref, fix => Variant[Struct[plan => ...], Struct[task => ...], Struct[command => ...]
        #
        fixes_builder = Puppet::Fix::FixesBuilder.new(issue.mnemonic)
        available_fixes = fixes_builder.build_fixes(result)
        return { nodes => available_fixes[issue] || Puppet::Fix::Model::NoFix.new }
      end
    end
  end
end
