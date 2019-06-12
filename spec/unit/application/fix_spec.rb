require 'spec_helper'
require 'puppet_spec/files'
require 'puppet_pal'

require 'puppet/application/fix'
require 'puppet/file_bucket/dipper'
require 'puppet/configurer'
require 'fileutils'

describe Puppet::Application::Fix do
  include PuppetSpec::Files

  before :each do
    @apply = Puppet::Application[:fix]
    allow(Puppet::Util::Log).to receive(:newdestination)
    Puppet[:reports] = "none"
  end

  after :each do
    Puppet::Node::Facts.indirection.reset_terminus_class
    Puppet::Node::Facts.indirection.cache_class = nil

    Puppet::Node.indirection.reset_terminus_class
    Puppet::Node.indirection.cache_class = nil
  end

  [:issue,].each do |option|
    it "should declare handle_#{option} method" do
      expect(@apply).to respond_to("handle_#{option}".to_sym)
    end

    it "should store argument value when calling handle_#{option}" do
      expect(@apply.options).to receive(:[]=).with(option, 'arg')
      @apply.send("handle_#{option}".to_sym, 'arg')
    end
  end

  describe "when applying options" do
    it "should set the log destination with --logdest" do
      expect(Puppet::Log).to receive(:newdestination).with("console")

      @apply.handle_logdest("console")
    end

    it "should set the setdest options to true" do
      expect(@apply.options).to receive(:[]=).with(:setdest,true)

      @apply.handle_logdest("console")
    end
  end

  #  it "should set the code to the provided code when :execute is used" do
  #    expect(@apply.options).to receive(:[]=).with(:code, 'arg')
  #    @apply.send("handle_execute".to_sym, 'arg')
  #  end

#  describe "during setup" do
#    before :each do
#      allow(Puppet::Log).to receive(:newdestination)
#      allow(Puppet::FileBucket::Dipper).to receive(:new)
#      allow(STDIN).to receive(:read)
#      allow(Puppet::Transaction::Report.indirection).to receive(:cache_class=)
#    end
#
#    describe "with --test" do
#      it "should call setup_test" do
#        @apply.options[:test] = true
#        expect(@apply).to receive(:setup_test)
#
#        @apply.setup
#      end
#
#      it "should set options[:verbose] to true" do
#        @apply.setup_test
#
#        expect(@apply.options[:verbose]).to eq(true)
#      end
#      it "should set options[:show_diff] to true" do
#        Puppet.settings.override_default(:show_diff, false)
#        @apply.setup_test
#        expect(Puppet[:show_diff]).to eq(true)
#      end
#      it "should set options[:detailed_exitcodes] to true" do
#        @apply.setup_test
#
#        expect(@apply.options[:detailed_exitcodes]).to eq(true)
#      end
#    end
#
    it "should set console as the log destination if logdest option wasn't provided" do
      expect(Puppet::Log).to receive(:newdestination).with(:console)

      @apply.setup
    end

    it "sets the log destination if logdest is provided via settings" do
      expect(Puppet::Log).to receive(:newdestination).with("set_via_config")
      Puppet[:logdest] = "set_via_config"

      @apply.setup
    end

    it "should set INT trap" do
      expect(Signal).to receive(:trap).with(:INT)

      @apply.setup
    end

    it "should set log level to debug if --debug was passed" do
      @apply.options[:debug] = true
      @apply.setup
      expect(Puppet::Log.level).to eq(:debug)
    end

    it "should not tell the report handler to cache" do
      expect(Puppet::Transaction::Report.indirection).to_not receive(:cache_class=)

      @apply.setup
    end

    context 'When parsing given issue' do
      it 'Parses a given issue when given on the command line with -i' do
        @apply.options[:issue] = 'abc::def::1.2.3_Some name'
        @apply.main
        parsed_issue = @apply.options[:parsed_issue]
        expect(parsed_issue['mnemonic']).to eql('abc::def')
      end

      it 'Raises an exception if there is no reference to a benchmark in the given issue' do
        @apply.setup
        @apply.options[:issue] = '1.1.1'
        expect { @apply.main }.to raise_error(/No benchmark was given and 'default_benchmark' is not set/)
      end

      it 'Raises an exception if there is no reference to a benchmark in the given issue' do
        @apply.options[:issue] = 'abc::'
        @apply.setup
        expect { @apply.main }.to raise_error(/No reference to an issue was given, needs either a <section> or a <name> to match against/)
      end

      it 'Should return a hash with menmonic, section and name' do
        result = @apply.parse_issue("abc::1.2.3_Do_not_use_a_well_known_root_password")
        expect(result['mnemonic']).to eql("abc")
        expect(result['section']).to eql("1.2.3")
        expect(result['name']).to eql("Do_not_use_a_well_known_root_password")
      end

      it 'A menmonic can be a qualified name' do
        result = @apply.parse_issue("abc::def::1.2.3_Do_not_use_a_well_known_root_password")
        expect(result['mnemonic']).to eql("abc::def")
        expect(result['section']).to eql("1.2.3")
        expect(result['name']).to eql("Do_not_use_a_well_known_root_password")
      end

      it 'A section given with _ separators is normalized to . separators' do
        result = @apply.parse_issue("abc::1_2_3_Do_not_use_a_well_known_root_password")
        expect(result['section']).to eql("1.2.3")
      end

      it 'menmonic is optional' do
        result = @apply.parse_issue("1_2_3_Do_not_use_a_well_known_root_password")
        expect(result['mnemonic']).to be_nil
        expect(result['section']).to eql("1.2.3")
        expect(result['name']).to eql("Do_not_use_a_well_known_root_password")
      end

      it 'section is optional' do
        result = @apply.parse_issue("Do_not_use_a_well_known_root_password")
        expect(result['mnemonic']).to be_nil
        expect(result['section']).to be_nil
        expect(result['name']).to eql("Do_not_use_a_well_known_root_password")
      end

      it 'Leading separator is dropped even if only name is given' do
        result = @apply.parse_issue("_Do_not_use_a_well_known_root_password")
        expect(result['mnemonic']).to be_nil
        expect(result['section']).to be_nil
        expect(result['name']).to eql("Do_not_use_a_well_known_root_password")
      end

      it 'Separator before name can be . or _' do
        result = @apply.parse_issue(".Do_not_use_a_well_known_root_password")
        expect(result['mnemonic']).to be_nil
        expect(result['section']).to be_nil
        expect(result['name']).to eql("Do_not_use_a_well_known_root_password")
      end

      it 'no input returns nil for all values' do
        result = @apply.parse_issue("")
        expect(result['mnemonic']).to be_nil
        expect(result['section']).to be_nil
        expect(result['name']).to be_nil
      end

      it 'Accepts section without name' do
        result = @apply.parse_issue("abc::1_2_3")
        expect(result['mnemonic']).to eql("abc")
        expect(result['section']).to eql("1.2.3")
        expect(result['name']).to be_nil
      end

      it 'Accepts section only' do
        result = @apply.parse_issue("1_2_3")
        expect(result['mnemonic']).to be_nil
        expect(result['section']).to eql("1.2.3")
        expect(result['name']).to be_nil
      end
    end

    context 'when handling options' do
      it 'is not allowed to specify both --issue and --issues_file' do
        @apply.options[:issue] = 'abc::def::1.2.3_Some name'
        @apply.options[:issues_file] = 'somefile.yaml'
        expect { @apply.main }.to raise_error(/--issue and --issues_file cannot be used at the same time/)
      end
    end

    context 'handles settings' do
      it 'setup loads "fixconf.yaml"' do
        allow(YAML).to receive(:load_file) { { } }
        @apply.setup
      end

      it 'content from "fixconf.yaml" is loaded into fix_config attribute' do
        allow(YAML).to receive(:load_file) { { 'benchmarks' => [] } }
        @apply.setup
        expect(@apply.fix_config['benchmarks']).to be_a(Array)
      end
    end

    context 'loads content from modules' do
      let(:testing_env) do
        {
          'pal_env' => {
            'functions' => functions,
            'lib' => { 'puppet' => lib_puppet },
            'manifests' => manifests,
            'modules' => modules,
            'plans' => plans,
            'tasks' => tasks,
            'types' => types,
            'data' => data,
            'hiera.yaml' => env_hiera,
          },
        }
      end

      # Bind these to hashes representing filename => content
      let(:functions) { {} }
      let(:manifests) { {} }
      let(:modules) { {} }
      let(:plans) { {} }
      let(:lib_puppet) { {} }
      let(:tasks) { {} }
      let(:types) { {} }
      let(:data) { {} }
      let(:env_hiera) { nil }

      let(:environments_dir) { Puppet[:environmentpath] }

      let(:testing_env_dir) do
        dir_contained_in(environments_dir, testing_env)
        env_dir = File.join(environments_dir, 'pal_env')
        PuppetSpec::Files.record_tmp(env_dir)
        env_dir
      end

      let(:modules_dir) { File.join(testing_env_dir, 'modules') }

      context 'loads from hiera' do
        let(:env_hiera) { <<-YAML.unindent
          ---
          version: 5
          defaults:
            data_hash: yaml_data
            datadir: data
          hierarchy:
            - name: 'common'
              path: 'common.yaml'
          YAML
        }

        let(:data) {
          { 'common.yaml' => common_data }
        }

        let(:common_data) { <<-YAML.unindent
          ---
          benchmarks:
            - id: 'test benchmark'
              facts: {
                benchmark: {
                  name: 'tesbm'
                  family: 'cis'
                  version: '1.2.3'
                }
                os: {
                  name: "RedHat"
                  family: "RedHat"
                  release: {
                    full: "7.2.1511"
                    major: "7"
                    minor: "2"
                  }
                }
              }
        YAML
        }
        it 'can do a lookup' do
          pending("lookups does not work")
          Puppet::Log.newdestination(:console)
          x = testing_env_dir
          result = Puppet::Pal.in_environment('pal_env', env_dir: testing_env_dir, facts: {}) do |ctx|
            Puppet::Log.newdestination(:console)
            ctx.with_script_compiler {|c| c.evaluate_string('lookup(benchmarks, default_value => "sorry, I am broken")') }
          end
          expect(result).to eq("make me happy")

        end

      end
    end
#
#    it "configures a profiler when profiling is enabled" do
#      Puppet[:profile] = true
#
#      @apply.setup
#
#      expect(Puppet::Util::Profiler.current).to satisfy do |ps|
#        ps.any? {|p| p.is_a? Puppet::Util::Profiler::WallClock }
#      end
#    end
#
#    it "does not have a profiler if profiling is disabled" do
#      Puppet[:profile] = false
#
#      @apply.setup
#
#      expect(Puppet::Util::Profiler.current.length).to be 0
#    end
#
#    it "should set default_file_terminus to `file_server` to be local" do
#      expect(@apply.app_defaults[:default_file_terminus]).to eq(:file_server)
#    end
#  end
#
#  describe "when executing" do
#    it "should dispatch to 'apply' if it was called with 'apply'" do
#      @apply.options[:catalog] = "foo"
#
#      expect(@apply).to receive(:apply)
#      @apply.run_command
#    end
#
#    it "should dispatch to main otherwise" do
#      allow(@apply).to receive(:options).and_return({})
#
#      expect(@apply).to receive(:main)
#      @apply.run_command
#    end
#
#    describe "the main command" do
#      before :each do
#        Puppet[:prerun_command] = ''
#        Puppet[:postrun_command] = ''
#
#        Puppet::Node::Facts.indirection.terminus_class = :memory
#        Puppet::Node::Facts.indirection.cache_class = :memory
#        Puppet::Node.indirection.terminus_class = :memory
#        Puppet::Node.indirection.cache_class = :memory
#
#        @facts = Puppet::Node::Facts.new(Puppet[:node_name_value])
#        Puppet::Node::Facts.indirection.save(@facts)
#
#        @node = Puppet::Node.new(Puppet[:node_name_value])
#        Puppet::Node.indirection.save(@node)
#
#        @catalog = Puppet::Resource::Catalog.new("testing", Puppet.lookup(:environments).get(Puppet[:environment]))
#        allow(@catalog).to receive(:to_ral).and_return(@catalog)
#
#        allow(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(@catalog)
#
#        allow(STDIN).to receive(:read)
#
#        @transaction = double('transaction')
#        allow(@catalog).to receive(:apply).and_return(@transaction)
#
#        allow(Puppet::Util::Storage).to receive(:load)
#        allow_any_instance_of(Puppet::Configurer).to receive(:save_last_run_summary) # to prevent it from trying to write files
#      end
#
#      after :each do
#        Puppet::Node::Facts.indirection.reset_terminus_class
#        Puppet::Node::Facts.indirection.cache_class = nil
#      end
#
#      around :each do |example|
#        Puppet.override(:current_environment =>
#                        Puppet::Node::Environment.create(:production, [])) do
#          example.run
#        end
#      end
#
#      it "should set the code to run from --code" do
#        @apply.options[:code] = "code to run"
#        expect(Puppet).to receive(:[]=).with(:code,"code to run")
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should set the code to run from STDIN if no arguments" do
#        allow(@apply.command_line).to receive(:args).and_return([])
#        allow(STDIN).to receive(:read).and_return("code to run")
#
#        expect(Puppet).to receive(:[]=).with(:code,"code to run")
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should raise an error if a file is passed on command line and the file does not exist" do
#        noexist = tmpfile('noexist.pp')
#        allow(@apply.command_line).to receive(:args).and_return([noexist])
#        expect { @apply.main }.to raise_error(RuntimeError, "Could not find file #{noexist}")
#      end
#
#      it "should set the manifest to the first file and warn other files will be skipped" do
#        manifest = tmpfile('starwarsIV')
#        FileUtils.touch(manifest)
#
#        allow(@apply.command_line).to receive(:args).and_return([manifest, 'starwarsI', 'starwarsII'])
#
#        expect { @apply.main }.to exit_with 0
#
#        msg = @logs.find {|m| m.message =~ /Only one file can be applied per run/ }
#        expect(msg.message).to eq('Only one file can be applied per run.  Skipping starwarsI, starwarsII')
#        expect(msg.level).to eq(:warning)
#      end
#
#      it "should splay" do
#        expect(@apply).to receive(:splay)
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should raise an error if we can't find the node" do
#        expect(Puppet::Node.indirection).to receive(:find).and_return(nil)
#
#        expect { @apply.main }.to raise_error(RuntimeError, /Could not find node/)
#      end
#
#      it "should load custom classes if loadclasses" do
#        @apply.options[:loadclasses] = true
#        classfile = tmpfile('classfile')
#        File.open(classfile, 'w') { |c| c.puts 'class' }
#        Puppet[:classfile] = classfile
#
#        expect(@node).to receive(:classes=).with(['class'])
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should compile the catalog" do
#        expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(@catalog)
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it 'should called the DeferredResolver to resolve any Deferred values' do
#        expect(Puppet::Pops::Evaluator::DeferredResolver).to receive(:resolve_and_replace).with(any_args)
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it 'should make the Puppet::Pops::Loaders available when applying the compiled catalog' do
#        expect(Puppet::Resource::Catalog.indirection).to receive(:find).and_return(@catalog)
#        expect(@apply).to receive(:apply_catalog) do |catalog|
#          expect(@catalog).to eq(@catalog)
#          fail('Loaders not found') unless Puppet.lookup(:loaders) { nil }.is_a?(Puppet::Pops::Loaders)
#          true
#        end.and_return(0)
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should transform the catalog to ral" do
#        expect(@catalog).to receive(:to_ral).and_return(@catalog)
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should finalize the catalog" do
#        expect(@catalog).to receive(:finalize)
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should not save the classes or resource file by default" do
#        expect(@catalog).not_to receive(:write_class_file)
#        expect(@catalog).not_to receive(:write_resource_file)
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should save the classes and resources files when requested" do
#        @apply.options[:write_catalog_summary] = true
#
#        expect(@catalog).to receive(:write_class_file).once
#        expect(@catalog).to receive(:write_resource_file).once
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should call the prerun and postrun commands on a Configurer instance" do
#        expect_any_instance_of(Puppet::Configurer).to receive(:execute_prerun_command).and_return(true)
#        expect_any_instance_of(Puppet::Configurer).to receive(:execute_postrun_command).and_return(true)
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should apply the catalog" do
#        expect(@catalog).to receive(:apply).and_return(double('transaction'))
#
#        expect { @apply.main }.to exit_with 0
#      end
#
#      it "should save the last run summary" do
#        Puppet[:noop] = false
#        report = Puppet::Transaction::Report.new
#        allow(Puppet::Transaction::Report).to receive(:new).and_return(report)
#
#        expect_any_instance_of(Puppet::Configurer).to receive(:save_last_run_summary).with(report)
#        expect { @apply.main }.to exit_with 0
#      end
#
#      describe "when using node_name_fact" do
#        before :each do
#          @facts = Puppet::Node::Facts.new(Puppet[:node_name_value], 'my_name_fact' => 'other_node_name')
#          Puppet::Node::Facts.indirection.save(@facts)
#          @node = Puppet::Node.new('other_node_name')
#          Puppet::Node.indirection.save(@node)
#          Puppet[:node_name_fact] = 'my_name_fact'
#        end
#
#        it "should set the facts name based on the node_name_fact" do
#          expect { @apply.main }.to exit_with 0
#          expect(@facts.name).to eq('other_node_name')
#        end
#
#        it "should set the node_name_value based on the node_name_fact" do
#          expect { @apply.main }.to exit_with 0
#          expect(Puppet[:node_name_value]).to eq('other_node_name')
#        end
#
#        it "should merge in our node the loaded facts" do
#          @facts.values.merge!('key' => 'value')
#
#          expect { @apply.main }.to exit_with 0
#
#          expect(@node.parameters['key']).to eq('value')
#        end
#
#        it "should raise an error if we can't find the facts" do
#          expect(Puppet::Node::Facts.indirection).to receive(:find).and_return(nil)
#
#          expect { @apply.main }.to raise_error(RuntimeError, /Could not find facts/)
#        end
#      end
#
#      describe "with detailed_exitcodes" do
#        before :each do
#          @apply.options[:detailed_exitcodes] = true
#        end
#
#        it "should exit with report's computed exit status" do
#          Puppet[:noop] = false
#          allow_any_instance_of(Puppet::Transaction::Report).to receive(:exit_status).and_return(666)
#
#          expect { @apply.main }.to exit_with 666
#        end
#
#        it "should exit with report's computed exit status, even if --noop is set" do
#          Puppet[:noop] = true
#          allow_any_instance_of(Puppet::Transaction::Report).to receive(:exit_status).and_return(666)
#
#          expect { @apply.main }.to exit_with 666
#        end
#
#        it "should always exit with 0 if option is disabled" do
#          Puppet[:noop] = false
#          report = double('report', :exit_status => 666)
#          allow(@transaction).to receive(:report).and_return(report)
#
#          expect { @apply.main }.to exit_with 0
#        end
#
#        it "should always exit with 0 if --noop" do
#          Puppet[:noop] = true
#          report = double('report', :exit_status => 666)
#          allow(@transaction).to receive(:report).and_return(report)
#
#          expect { @apply.main }.to exit_with 0
#        end
#      end
#    end
#
#    describe "the 'apply' command" do
#      # We want this memoized, and to be able to adjust the content, so we
#      # have to do it ourselves.
#      def temporary_catalog(content = '"something"')
#        @tempfile = Tempfile.new('catalog.json')
#        @tempfile.write(content)
#        @tempfile.close
#        @tempfile.path
#      end
#
#      let(:default_format) { Puppet::Resource::Catalog.default_format }
#      it "should read the catalog in from disk if a file name is provided" do
#        @apply.options[:catalog] = temporary_catalog
#        catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
#        allow(Puppet::Resource::Catalog).to receive(:convert_from).with(default_format, '"something"').and_return(catalog)
#        @apply.apply
#      end
#
#      it "should read the catalog in from stdin if '-' is provided" do
#        @apply.options[:catalog] = "-"
#        expect($stdin).to receive(:read).and_return('"something"')
#        catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
#        allow(Puppet::Resource::Catalog).to receive(:convert_from).with(default_format, '"something"').and_return(catalog)
#        @apply.apply
#      end
#
#      it "should deserialize the catalog from the default format" do
#        @apply.options[:catalog] = temporary_catalog
#        allow(Puppet::Resource::Catalog).to receive(:default_format).and_return(:rot13_piglatin)
#        catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
#        allow(Puppet::Resource::Catalog).to receive(:convert_from).with(:rot13_piglatin,'"something"').and_return(catalog)
#        @apply.apply
#      end
#
#      it "should fail helpfully if deserializing fails" do
#        @apply.options[:catalog] = temporary_catalog('something syntactically invalid')
#        expect { @apply.apply }.to raise_error(Puppet::Error)
#      end
#
#      it "should convert the catalog to a RAL catalog and use a Configurer instance to apply it" do
#        @apply.options[:catalog] = temporary_catalog
#        catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
#        allow(Puppet::Resource::Catalog).to receive(:convert_from).with(default_format, '"something"').and_return(catalog)
#        expect(catalog).to receive(:to_ral).and_return("mycatalog")
#
#        configurer = double('configurer')
#        expect(Puppet::Configurer).to receive(:new).and_return(configurer)
#        expect(configurer).to receive(:run).
#          with(:catalog => "mycatalog", :pluginsync => false)
#
#        @apply.apply
#      end
#
#      it 'should make the Puppet::Pops::Loaders available when applying a catalog' do
#        @apply.options[:catalog] = temporary_catalog
#        catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
#        expect(@apply).to receive(:read_catalog) do |arg|
#          expect(arg).to eq('"something"')
#          fail('Loaders not found') unless Puppet.lookup(:loaders) { nil }.is_a?(Puppet::Pops::Loaders)
#          true
#        end.and_return(catalog)
#        expect(@apply).to receive(:apply_catalog) do |cat|
#          expect(cat).to eq(catalog)
#          fail('Loaders not found') unless Puppet.lookup(:loaders) { nil }.is_a?(Puppet::Pops::Loaders)
#          true
#        end
#        expect { @apply.apply }.not_to raise_error
#      end
#
#      it "should call the DeferredResolver to resolve Deferred values" do
#        @apply.options[:catalog] = temporary_catalog
#        allow(Puppet::Resource::Catalog).to receive(:default_format).and_return(:rot13_piglatin)
#        catalog = Puppet::Resource::Catalog.new("testing", Puppet::Node::Environment::NONE)
#        allow(Puppet::Resource::Catalog).to receive(:convert_from).with(:rot13_piglatin, '"something"').and_return(catalog)
#        expect(Puppet::Pops::Evaluator::DeferredResolver).to receive(:resolve_and_replace).with(any_args)
#        @apply.apply
#      end
#    end
#  end
#
#  describe "when really executing" do
#    let(:testfile) { tmpfile('secret_file_name') }
#    let(:resourcefile) { tmpfile('resourcefile') }
#    let(:classfile) { tmpfile('classfile') }
#
#    it "should not expose sensitive data in the relationship file" do
#      @apply.options[:code] = <<-CODE
#        $secret = Sensitive('cat #{testfile}')
#
#        exec { 'do it':
#          command => $secret,
#          path    => '/bin/'
#        }
#      CODE
#
#      @apply.options[:write_catalog_summary] = true
#
#      Puppet.settings[:resourcefile] = resourcefile
#      Puppet.settings[:classfile] = classfile
#
#      #We don't actually need the resource to do anything, we are using it's properties in other parts of the workflow.
#      allow(Puppet::Util::Execution).to receive(:execute)
#
#      expect { @apply.main }.to exit_with 0
#
#      result = File.read(resourcefile)
#
#      expect(result).not_to match(/secret_file_name/)
#      expect(result).to match(/do it/)
#    end
#  end
#
#  describe "apply_catalog" do
#    it "should call the configurer with the catalog" do
#      catalog = "I am a catalog"
#      expect_any_instance_of(Puppet::Configurer).to receive(:run).
#        with(:catalog => catalog, :pluginsync => false)
#      @apply.send(:apply_catalog, catalog)
#    end
#  end
#
#  it "should honor the catalog_cache_terminus setting" do
#    Puppet.settings[:catalog_cache_terminus] = "json"
#    expect(Puppet::Resource::Catalog.indirection).to receive(:cache_class=).with(:json)
#
#    @apply.initialize_app_defaults
#    @apply.setup
#  end
end
