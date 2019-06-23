require 'spec_helper'
require 'puppet/fix/fix_model'

describe 'ReportedIssue' do

  let(:testissue) do
    Puppet::Fix::Model::Issue.new(mnemonic: 'abc', section: '1.1.1', name: 'test-issue')
  end

  it 'can be created by giving an issue and no nodes' do 
    ri = Puppet::Fix::Model::ReportedIssue.new(testissue)
    expect(ri.nodes).to be_a(Set)
    expect(ri.nodes).to be_empty
  end

  it 'can be created by giving an issue and nodes' do 
    ri = Puppet::Fix::Model::ReportedIssue.new(testissue, 'kermit', 'gonzo')
    expect(ri.nodes).to be_a(Set)
    expect(ri.nodes).to eq(Set['kermit', 'gonzo'])
  end

  it 'nodes can be added' do
    ri = Puppet::Fix::Model::ReportedIssue.new(testissue, 'kermit', 'gonzo')
    ri.add_nodes('animal', 'waldorf')
    ri.add_nodes('waldorf')
    expect(ri.nodes).to eq(Set['animal', 'kermit', 'gonzo', 'waldorf'])
  end

  it 'modifying state does not modify returned nodes' do
    ri = Puppet::Fix::Model::ReportedIssue.new(testissue, 'kermit', 'gonzo')
    nodes = ri.nodes
    ri.add_nodes('waldorf')
    expect(ri.nodes).to_not eq(nodes)
  end

  it 'returned nodes are frozen along with its contained strings' do
    ri = Puppet::Fix::Model::ReportedIssue.new(testissue, 'kermit', 'gonzo')
    nodes = ri.nodes
    expect(nodes.frozen?).to be(true)
    expect(nodes.all? {|n| n.frozen? }).to be(true)
  end

end
