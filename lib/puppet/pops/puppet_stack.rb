module Puppet::Pops
# Module for making a call such that there is an identifiable entry on
# the ruby call stack enabling getting a puppet call stack
# To use this make a call with:
# ```
# Puppet::Pops::PuppetStack.stack(file, line, receiver, message, args)
# ```
# To get the stack call:
# ```
# Puppet::Pops::PuppetStack.stacktrace
#
# When getting a backtrace in Ruby, the puppet stack frames are
# identified as coming from "in 'stack'" and having a ".pp" file
# name.
# To support testing, a given file that is an empty string, or nil
# as well as a nil line number are supported. Such stack frames
# will be represented with the text `unknown` and `0´ respectively.
# @api public
module PuppetStack
  # Sends a message to an obj such that it appears to come from
  # file, line when calling stacktrace.
  # @api private
  #
  def self.stack(file, line, obj, message, args, &block)
    file = '' if file.nil?
    line = 0 if line.nil?

    if block_given?
      Kernel.eval("obj.send(message, *args, &block)", Kernel.binding(), file, line)
    else
      Kernel.eval("obj.send(message, *args)", Kernel.binding(), file, line)
    end
  end

  # Returns the puppet stacktrace of function calls.
  # The innermost nested function call appears first in an array of tuples containing the file and line
  # information. If file is not known, the text "unknown" is found in this position. All other locations
  # are a reference to a file ending with ".pp". The line number is always present and is an Integer.
  # @api public
  #
  def self.stacktrace
    caller().reduce([]) do |memo, loc|
      if loc =~ /^(.*\.pp)?:([0-9]+):in (`stack'|`block in call_function')/
        memo << [$1.nil? ? 'unknown' : $1, $2.to_i]
      end
      memo
    end
  end
end
end
