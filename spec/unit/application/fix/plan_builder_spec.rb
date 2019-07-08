require 'spec_helper'
require 'puppet/fix'

describe 'PlanBuilder' do

  let(:sample_hash) do
    { 'id'      => 'http://somplace.org/unique-name',  # "their" identity
      'name'    => 'fixname',                          # Puppet fix identity
      'family'  => 'testbm',                           # Puppet fix grouping of bm's
      'version' => '1.2.3',                            # "their" version
      'facts'   => {
        'os' => {
          'family' => 'os.family.test'
        }
      }
    }
  end

  let(:sample_bm) do
    Puppet::Fix::Model::Benchmark.from_hash(sample_hash)
  end

  let(:no_fix_fix_provider) { self.class::NoFixFixProvider.new }
  let(:test_fix_provider) { self.class::TestFixProvider.new }

  class self::NoFixFixProvider
    def find_fixes(issue:, nodes:, facts:)
      { nodes => Puppet::Fix::Model::NoFix.new }
    end
  end

  class self::TestFixProvider
    def find_fixes(issue:, nodes:, facts:)
      case issue.section
      when '1.1.1'
        # Same TASK for all nodes
        #
        { nodes => Puppet::Fix::Model::TaskFix.new('mytask') }
      when '1.1.2'
        # Different TASK parameter for tasks endingt with '.test'
        # 
        classified = nodes.classify {|n| n.end_with?('.test') ? :test : :prod }
        {
          classified[:test] => Puppet::Fix::Model::TaskFix.new('mytask', 'env' => 'test'),
          classified[:prod] => Puppet::Fix::Model::TaskFix.new('mytask', 'env' => 'production'),
        }
      when '2.1.1'
          # Same PLAN for all nodes
          #
        { nodes => Puppet::Fix::Model::PlanFix.new('myplan') }
      when '3.1.1'
        # Same COMMAND for all nodes
        #
        { nodes => Puppet::Fix::Model::CommandFix.new('@echo all is well') }
      when '4.1.1'
        # Same Skipped for all nodes
        #
        { nodes => Puppet::Fix::Model::SkippedFix.new() }
      else
        # NO FIX
        #
        { nodes => Puppet::Fix::Model::NoFix.new }
      end
    end
  end

  context 'when initialized' do
    it 'can be created with a fix provider' do 
      expect {Puppet::Fix::Model::PlanBuilder.new(fix_provider: no_fix_fix_provider)}.to_not raise_error
    end

    it 'has a default name for the plan' do
      builder = Puppet::Fix::Model::PlanBuilder.new(fix_provider: no_fix_fix_provider)
      expect(builder.plan_name).to eq('generated_plan')
    end

    it 'uses a given plan name' do
      builder = Puppet::Fix::Model::PlanBuilder.new(fix_provider: no_fix_fix_provider, plan_name: 'plan_b')
      expect(builder.plan_name).to eq('plan_b')
    end
  end

  context 'dealing with benchmarks and defining issues' do
    # Benchmarks must be defined before issues can reference them
    #
    let(:builder) do
      Puppet::Fix::Model::PlanBuilder.new(fix_provider: no_fix_fix_provider)
    end

    it 'accepts added definition of benchmarks' do
      expect {
        builder.add_benchmark(sample_bm)
      }.to_not raise_error
    end

    it 'does not accept adding issue by ref referencing unknown benchmark' do
      expect { 
        builder.add_issue_ref('nope:/1.2.3_problem')
      }.to raise_error(/Given issue references unknown benchmark/)
    end

    it 'does not accept adding Issue referencing unknown benchmark' do
      expect {
        builder.add_issue(Puppet::Fix::Model::Issue.parse_issue('nope:/:1.2.3_problem'))
      }.to raise_error(/Given issue references unknown benchmark/)
    end

    it 'accepts added issue by ref for defined benchmark' do
      builder.add_benchmark(sample_bm)
      expect {
        builder.add_issue_ref('fixname:/1.2.3_problem')
      }.to_not raise_error
    end

    it 'accepts added issue for defined benchmark' do
      builder.add_benchmark(sample_bm)
      expect {
        builder.add_issue(Puppet::Fix::Model::Issue.parse_issue('fixname:/1.2.3_problem'))
      }.to_not raise_error
    end
  end

  # Can add ReportedIssues
  # Can add ReportedIssues multiple times...
  # Adding issue multiple times does not alter state
  # Added "ignored issues" are ignored
  # 'produce_plan' produces a plan
  #     * option include all issues even if not reported
  #     * 

  context 'when adding ReportedIssues' do
    # Benchmarks must be defined before issues can reference them
    # Issues must not be defined before adding ReportedIssue.
    # The issue referenced in the ReportedIssue will be added to the
    # set of known issues.
    # Benchmarks must be defined before issues can reference them
    #
    let(:builder) do
      b = Puppet::Fix::Model::PlanBuilder.new(fix_provider: no_fix_fix_provider)
      b.add_benchmark(sample_bm)
      b
    end

    let(:sample_issue1) do
      Puppet::Fix::Model::Issue.parse_issue('fixname:/1.2.3_problem')
    end

    let(:sample_issue2) do
      Puppet::Fix::Model::Issue.parse_issue('fixname:/1.2.3_problem')
    end

    let(:unknown_issue) do
      Puppet::Fix::Model::Issue.parse_issue('unknown:/1.2.3_problem')
    end

    it 'accepts a reported issue referencing a known benchmark' do
      expect {
        builder.add_reported_issue(sample_issue1, 'kermit', 'gonzo')
      }.to_not raise_error
    end

    it 'does not accept a reported issue referencing an unknown benchmark' do
      expect {
        builder.add_reported_issue(unknown_issue, 'kermit', 'gonzo')
      }.to raise_error(/Given issue references unknown benchmark/)
    end
  end

  context 'when generating a plan' do
    let(:builder) do
      b = Puppet::Fix::Model::PlanBuilder.new(fix_provider: test_fix_provider)
      b.add_benchmark(sample_bm)
      b
    end

    context 'in general' do
      it 'starts with a header' do
        allow(Time).to receive(:now).and_return('a dark desert highway')
        result = builder.produce_plan

        lines = result.split("\n")

        expected_lines = [
          '## Puppet Fix generated remediation plan',
          "## Created on a dark desert highway",
          '##',
        ]
        (0..2).each do | i |
          expect(lines[i]).to eq(expected_lines[i])
        end
      end
    end

    context 'and there are no reported issues' do
      it 'generates an empty plan' do
        result = builder.produce_plan
        # drop the header
        lines = result.split("\n")[4..-1]

        expected_lines = [
          'plan generated_plan() {',
          "}",
        ]
        (0..1).each do | i |
          expect(lines[i]).to eq(expected_lines[i])
        end
      end
    end

    context 'and there are reported issues' do
      let(:builder) do
        b = Puppet::Fix::Model::PlanBuilder.new(fix_provider: test_fix_provider)
        b.add_benchmark(sample_bm)
        # add reported issues
        b.add_reported_issue(b.add_issue_ref('fixname:/1.1.1_should-be-good'), 'kermit', 'gonzo')
        b.add_reported_issue(b.add_issue_ref('fixname:/2.1.1_should-not-be-bad'), 'kermit', 'gonzo', 'piggy')
        b.add_reported_issue(b.add_issue_ref('fixname:/3.1.1_no-bad-enabled'), 'kermit', 'gonzo')
        b.add_reported_issue(b.add_issue_ref('fixname:/4.1.1_without-security-holes'), 'kermit', 'gonzo', 'waldorf')
        b.add_reported_issue(b.add_issue_ref('fixname:/5.1.1_be-nice-to-everyone'), 'kermit', 'gonzo')
        b
      end

      it 'produces a plan' do
        expect { builder.produce_plan }.to_not raise_error
      end

      # TODO: make assertions
      #       * does not create a node set if one exists already
      #       * creates node sets for fix provider splitted node sets
      #       * shows nodes for which there was a skip or not found
    end

  end
end
