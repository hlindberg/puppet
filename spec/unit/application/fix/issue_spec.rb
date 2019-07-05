require 'spec_helper'
require 'puppet/fix/fixes'

describe 'The Fix Model' do
  describe 'Issue' do
    it 'can be created by giving each part of the issue' do
      x = Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
      expect(x.name).to eq('test-issue')
      expect(x.mnemonic).to eq('abc')
      expect(x.section).to eq('1.1.1')
    end

    it 'can be created from a hash' do
      x = Puppet::Fix::Model::Issue.new_from_hash({'mnemonic' => 'abc', 'section' => '1.1.1', 'name' => 'test-issue'})
      expect(x.name).to eq('test-issue')
      expect(x.mnemonic).to eq('abc')
      expect(x.section).to eq('1.1.1')
    end

    it 'can be created from a string' do
      x = Puppet::Fix::Model::Issue.parse_issue('abc::1.1.1_test-issue')
      expect(x.name).to eq('test-issue')
      expect(x.mnemonic).to eq('abc')
      expect(x.section).to eq('1.1.1')

      x = Puppet::Fix::Model::Issue.parse_issue('abc::1.1.1-test-issue')
      expect(x.name).to eq('test-issue')
      expect(x.mnemonic).to eq('abc')
      expect(x.section).to eq('1.1.1')
    end

    it 'returns a normalized reference from #ref' do
      x = Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
      expect(x.ref).to eq('abc::1.1.1_test-issue')
    end

    it 'eql? method compares attribute equality' do
      x = Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
      y = Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
      z = Puppet::Fix::Model::Issue.new(mnemonic: 'abd', section: '1.1.1', name: 'test-issue')
      expect(x.eql?(y)).to be(true)
      expect(y.eql?(x)).to be(true)
      expect(x == y).to be(true)
      expect(y  == x).to be(true)
      expect(x.eql?(z)).to be(false)
      expect(x == z).to be(false)
    end

    it 'can be used as key in a hash' do
      x = Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
      y = Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
      z = { x => 'yay' }
      expect(z[x]).to eq('yay')
      expect(z[y]).to eq('yay')
    end

  end

end