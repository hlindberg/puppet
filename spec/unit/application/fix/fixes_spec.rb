require 'spec_helper'
require 'puppet/fix/fix_model'

describe 'Fixes' do

#  let(:sample_hash) do
#    { 'id'      => 'http://somplace.org/unique-name',  # "their" identity
#      'name'    => 'ourname',                          # Puppet fix identity
#      'family'  => 'testbm',                           # Puppet fix grouping of bm's
#      'version' => '1.2.3',                            # "their" version
#      'facts'   => {
#        'os' => {
#          'family' => 'os.family.test'
#        }
#      }
#    }
#  end

  let(:sample_targets) { ['kermit', 'gonzo'] }

  context 'NoFix' do
    it 'can be created without args' do 
      expect { Puppet::Fix::Model::NoFix.new }.to_not raise_error
    end

    it 'reports that it does not require targets' do
      f = Puppet::Fix::Model::NoFix.new
      expect(f.requires_targets?).to be(false)
    end

    it 'outputs single line comment when generating pp code' do
      f = Puppet::Fix::Model::NoFix.new
      # array with lines of text, indented 2 spaces
      expect(f.to_pp).to eq(['  ## Unavailable : No fix defined for this issue!'])
    end
  end

  context 'SkippedFix' do
    it 'can be created without args' do 
      expect { Puppet::Fix::Model::SkippedFix.new }.to_not raise_error
    end

    it 'reports that it does not require targets' do
      f = Puppet::Fix::Model::SkippedFix.new
      expect(f.requires_targets?).to be(false)
    end

    it 'outputs single line comment when generating pp code' do
      f = Puppet::Fix::Model::SkippedFix.new
      # array with lines of text, indented 2 spaces
      expect(f.to_pp).to eq(['  ## Skip        : Configured to be skipped!'])
    end
  end

  context 'PlanFix' do
    it 'can be created with plan name' do 
      expect { Puppet::Fix::Model::PlanFix.new('myplan') }.to_not raise_error
    end

    it 'can be created with plan name, and parameters hash' do 
      expect { Puppet::Fix::Model::PlanFix.new('myplan', {'x' => 42}) }.to_not raise_error
    end

    it 'reports that it requires targets' do
      f = Puppet::Fix::Model::PlanFix.new('myplan')
      expect(f.requires_targets?).to be(true)
    end

    it 'outputs a run_plan call (without parameters, when no parameters were given) when generating pp code' do
      f = Puppet::Fix::Model::PlanFix.new('myplan')
      expect(f.to_pp('$targets')).to eq(["  run_plan('myplan', $targets, )"])
    end

    it 'outputs a run_plan call (with parameters, when given) when generating pp code' do
      f = Puppet::Fix::Model::PlanFix.new('myplan', {'x' => 42, 'y' => 24})
      expect(f.to_pp('$targets')).to eq(["  run_plan('myplan', $targets, 'x' => 42, 'y' => 24, )"])
    end
  end

  context 'TaskFix' do
    it 'can be created with task name' do 
      expect { Puppet::Fix::Model::TaskFix.new('mytask') }.to_not raise_error
    end

    it 'can be created with task name, and parameters hash' do 
      expect { Puppet::Fix::Model::TaskFix.new('mytask', {'x' => 42}) }.to_not raise_error
    end

    it 'reports that it requires targets' do
      f = Puppet::Fix::Model::TaskFix.new('myplan')
      expect(f.requires_targets?).to be(true)
    end

    it 'outputs a run_task call (without parameters, when no parameters were given) when generating pp code' do
      f = Puppet::Fix::Model::TaskFix.new('mytask')
      expect(f.to_pp('$targets')).to eq(["  run_task('mytask', $targets, )"])
    end

    it 'outputs a run_task call (with parameters, when given) when generating pp code' do
      f = Puppet::Fix::Model::TaskFix.new('mytask', {'x' => 42, 'y' => 24})
      expect(f.to_pp('$targets')).to eq(["  run_task('mytask', $targets, 'x' => 42, 'y' => 24, )"])
    end
  end

  context 'CommandFix' do
    it 'can be created with command string' do 
      expect { Puppet::Fix::Model::CommandFix.new('@echo all is well') }.to_not raise_error
    end

    it 'can be created with command string, and parameters hash' do 
      expect { Puppet::Fix::Model::TaskFix.new('@echo all is well', {'x' => 42}) }.to_not raise_error
    end

    it 'reports that it requires targets' do
      f = Puppet::Fix::Model::CommandFix.new('@echo all is well')
      expect(f.requires_targets?).to be(true)
    end

    it 'outputs a run_command call (without parameters, when no parameters were given) when generating pp code' do
      f = Puppet::Fix::Model::CommandFix.new('@echo all is well')
      expect(f.to_pp('$targets')).to eq(["  run_command('@echo all is well', $targets, )"])
    end

    it 'outputs a run_command call (with parameters, when given) when generating pp code' do
      f = Puppet::Fix::Model::CommandFix.new('@echo all is well', {'x' => 42, 'y' => 24})
      expect(f.to_pp('$targets')).to eq(["  run_command('@echo all is well', $targets, 'x' => 42, 'y' => 24, )"])
    end
  end

end
