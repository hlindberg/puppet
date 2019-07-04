require 'puppet/application'
require 'puppet/configurer'
require 'puppet/util/profiler/aggregate'
require 'puppet/parser/script_compiler'
require 'puppet/fix'

class Puppet::Application::Fix < Puppet::Application

  option("--debug","-d")

  option("--issue ISSUE", "-i") do |arg|
    options[:issue] = the_issue = Puppet::Fix::FixController.parse_issue(arg)
    unless the_issue.mnemonic && the_issue.section
      raise "Given issue must reference a benchmark and contain the section"
    end
  end

  option("--plan NAME", "-p") do |arg|
    options[:plan_name] = arg
  end

  option("--output_file FILE", "-o") do |arg|
    options[:output_file] = arg
  end

  option("--logdest LOGDEST", "-l") do |arg|
    handle_logdest_arg(arg)
  end

  option("--explain")

  option("--fixdir DIR") do |arg|
    options[:fixdir] = arg
  end

  def summary
    _("Produces remediation fixes for issues found when scanning for benchmark compliance or vulnerabilities")
  end

  def help
    <<-HELP

puppet-fix(8) -- #{summary}
========

SYNOPSIS
--------
  Produces remediation fixes for issues found when scanning for benchmark compliance or vulnerabilities.


USAGE
-----
puppet fix [-h|--help] [-V|--version] [-d|--debug] [--explain]
  [--fixdir DIR]
  [-p|--plan] [-o|--output_file <FILE>|-|--]
  [-l|--logdest syslog|eventlog|<FILE>|console]
  [-i|--issue] [<FILE> [<FILE> ...]]
  <file>


DESCRIPTION
-----------
Puppet fix produces a bolt plan with remediation fixes for known found (or explicitly given)
issues, such as reported non compliance with benchmark "controls", or detected "vulnerabilities".

It does this by translating reported issues to a bolt plan containing a sequence of calls to
`run_task()`, `run_plan()`, and `run_command()` with the nodes per reported issue as targets, and with
task/plan-name or command-string obtained by looking up mappings from reported-issue id to
remediating bolt action.

Note that Puppet fix does not provide any scanning of target systems. Instead it acts
on what is reported from such scanners. Puppet fix defines its own yaml input format
for such reports and it is expected that external tools will provide translation to
this format from the specific format produced by the various scanners on the market.

Puppet fix operates on information in a directory; the "fixdir", where it expects to fine
a "fixconf.yaml" confguration file, optionally a "hiera.yaml" file and a "data" directory.
Optionally, the fixdir can contain a "modules" directory with a standard puppet modules
layout. The modules can contain "hiera.yaml" and "data". If a module defines benchmarks
it should contain a "benchmarks.yaml" in its root. (TODO: module benchmarks.yaml not yet
implemented).

Note that Puppet fix only operates on information about bolt tasks, plans, and commands; it does
not need access to the actual bolt artifacts. Those must however be present when running
the produced plan with bolt. This means that modules can be created containing only
mappings of issues to fixes provided by content in some other module present at runtime.

Reported issues are mapped to fixes via hiera. The fixdir level hiera can
bind such mappings to the key "fix::fixmap", and each contributing module
to the key '<mymodule>::fix::fixmap', where '<mymodule>' is the name of the module.
The bound value shoud be a hash with issue-id key and fix-id value.

Fixes described at the fixdir-level have higher precedence than those from modules.
Precedence between modules is undefined.


Benchmark Mnemonic
------------------
A fully qualified benchmark control is something like this:

xccdf_org.cisecurity.benchmarks_benchmark_2.2.0.1_CIS_Red_Hat_Enterprise_Linux_7_Benchmark/1.1.1.1_Ensure_mounting_of_cramfs_filesystem_is_disabled

Which is a horribly long thing to work with. Puppet fix therefore uses a short form mnemonic/moniker for these long identities.
Those are defined in a `fixconf.yaml` file that is read by Puppet Fix.

TODO: Later it will be possible to define benchmarks in modules.

---
benchmarks:
  - 
    benchmark:
      id: "xccdf_org.cisecurity.benchmarks_benchmark_2.2.0.1_CIS_Red_Hat_Enterprise_Linux_7_Benchmark"  version: "2.2.0.1"
      name: "cis-rhel7"
      family: "cis"
    facts: {
      os:
        name: "RedHat"
        family: "RedHat"
        release:
          full: "7.2.1511"
          major: "7"
          minor: "2"

  - benchmark:
      id: "xccdf_org.cisecurity.benchmarks_benchmark_2.2.0.1_CIS_Red_Hat_Enterprise_Linux_8_Benchmark"
      name: "cis-rhel8"
      # rest as for rhel7


This identifies benchmarks as 'cis-rhel7', 'cis-rhel8', etc. and also provides the variable values for switching
data sets and mappings in hiera.

OPTIONS
-------
* --explain
  Outputs hiera explain output to stderr for all hiera lookups done by Puppet Fix. This is intended for debugging
  where information is coming from.

* --issue, -i
  A single issue for which some action is wanted in the form of an URI on the form <mnemonic>://<node_name>/<section><title>.
  If given wihtout host as <mnemonic>:/<section> the generated plan will use a default "example.com" node name. The <title> of
  the section may be included (for convenience when copy pasting reported information) but is ignored as the section is the primary key.

* --fixdir DIR
  Tells puppet fix to use the given DIR as the directory where the environment to use is located.
  Defaults to current directory.

* --version:
  The version of the benchmark for which the given --benchmark is a reference into.

* --plan
  The name of the plan. Defaults to `generated_plan`

* --output_file, -o <FILE>
  If given Puppet fix will write the generated plan to this file instead of sending it to stdout. A file name of "-" is taken
  to mean stdout. A filename of "--" is taken to mean the (last :: separated segment) of the generated plan in the current directory
  with a ".pp" suffix. The given file will be created, or overwritten if it already exists.

* [<FILE> [<FILE> ...]]
  None, one or several filenames of yaml files containing reported issues in the Puppet fix specified format.

ADDITIONAL OPTIONS
------------------
* --help:
  Print this help message

* --trace
  In case of an error the stacktrace at the point where an exception occured is output.

* --debug
  Turns on debug level logging and special output. (TODO: this may clash with --explain such that producing double output. Also,
  there is currently no specific debug output from Puppet fix).

* --logdest:
  Where to send log messages. Choose between 'syslog' (the POSIX syslog
  service), 'eventlog' (the Windows Event Log), 'console', or the path to a log
  file. Defaults to 'console'.

  A path ending with '.json' will receive structured output in JSON format. The
  log file will not have an ending ']' automatically written to it due to the
  appending nature of logging. It must be appended manually to make the content
  valid JSON.

  A path ending with '.jsonl' will receive structured output in JSON Lines
  format.

EXAMPLES
--------
    $ puppet fix -i cis-rhel7:/1.1.1.1_Ensure_mounting_of_cramfs_filesysten_is_disabled
    $ puppet fix -i cis-rhel7:/1.1.1.1
    $ puppet fix -i cis-rhel7://kermit.com/1.1.1.1
    $ puppet fix -p plan_b --fixdir ~/fixtest issue_report1.yaml issue_report2.yaml

AUTHOR
------
Henrik Lindberg

COPYRIGHT
---------
Copyright (c) 2019 Puppet Inc., LLC Licensed under the Apache 2.0 License (<--TODO: Probably not)

HELP
  end

  def main
    # The tasks feature is always on
    Puppet[:tasks] = true

    controller = Puppet::Fix::FixController.new

    options[:output_file] ||= "-"  # default stdout

    # only pass options the controller understands
    controller_options = options.select {|k,_| [
        :issue,
        :plan_name,
        :explain,
        :fixdir,
        :output_file,
      ].include?(k) }
    controller_options[:issue_files] = command_line.args

    controller.run(**controller_options)

    exit(0)

    rescue => detail
      Puppet.log_exception(detail)
      exit(1)
  end

  def setup
    # TODO: Should read and print its own configuration (in addition to puppet's)
    # exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    handle_logdest_arg(Puppet[:logdest])
    Puppet::Util::Log.newdestination(:console) unless options[:setdest]

    Signal.trap(:INT) do
      $stderr.puts _("Exiting")
      exit(1)
    end

    # When running a script, the catalog is not relevant, and neither is caching of it
    Puppet::Resource::Catalog.indirection.cache_class = nil

    set_log_level

    # Configure profiling... TODO: This may not be of value
    if Puppet[:profile]
      @profiler = Puppet::Util::Profiler.add_profiler(Puppet::Util::Profiler::Aggregate.new(Puppet.method(:info), "fix"))
    end
  end

end
