require 'spec_helper'
require 'puppet/fix/fix_model'

describe 'Benchmark' do

  let(:sample_hash) do
    { 'id'      => 'http://somplace.org/unique-name',  # "their" identity
      'name'    => 'ourname',                          # Puppet fix identity
      'family'  => 'testbm',                           # Puppet fix grouping of bm's
      'version' => '1.2.3',                            # "their" version
      'facts'   => {
        'os' => {
          'family' => 'os.family.test'
        }
      }
    }
  end

  it 'can be created from a hash' do 
    bm = Puppet::Fix::Model::Benchmark.from_hash(sample_hash)
    expect(bm.id).to eq('http://somplace.org/unique-name')
    expect(bm.name).to eq('ourname')
    expect(bm.family).to eq('testbm')
    expect(bm.version).to eq('1.2.3')
    expect(bm.facts).to eq({'os' => { 'family' => 'os.family.test'}})
    expected_bm_facts = {
      'benchmark' => { 'name' => 'ourname', 'family' => 'testbm', 'version' => '1.2.3', 'id' => 'http://somplace.org/unique-name'}
    }
    expect(bm.all_facts).to eq(expected_bm_facts.merge({'os' => { 'family' => 'os.family.test'}}))
  end

  it 'can be created from keyword args' do 
    h = sample_hash
    bm = Puppet::Fix::Model::Benchmark.new(id: h['id'], name: h['name'], family: h['family'], version: h['version'], facts: h['facts'])
    expect(bm.id).to eq('http://somplace.org/unique-name')
    expect(bm.name).to eq('ourname')
    expect(bm.family).to eq('testbm')
    expect(bm.version).to eq('1.2.3')
    expect(bm.facts).to eq({'os' => { 'family' => 'os.family.test'}})
    expected_bm_facts = {
      'benchmark' => { 'name' => 'ourname', 'family' => 'testbm', 'version' => '1.2.3', 'id' => 'http://somplace.org/unique-name'}
    }
    expect(bm.all_facts).to eq(expected_bm_facts.merge({'os' => { 'family' => 'os.family.test'}}))
  end

end
