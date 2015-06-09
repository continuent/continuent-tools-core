# Copyright (C) 2014 Continuent, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License.  You may obtain
# a copy of the License at
# 
#         http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#
# Initial developer(s): Jeff Mace
# Contributor(s):

# The tungsten.rb file is exported into the gem from 
# https://code.google.com/p/tungsten-replicator/
require 'tungsten'

class TungstenUtil
  # A wrapper for running another Tungsten script. This will automatically
  # forward messages to the console and add any TungstenScript options to 
  # the command.
  def tungsten_cmd_result(command)
    original_fwd_state = forward_cmd_results?()
    begin
      if TI
        prefix = "export CONTINUENT_ROOT=#{TI.root()}; "
      else
        prefix = ""
      end
      
      forward_cmd_results?(true)
      return cmd_result("#{prefix}#{command} #{get_tungsten_command_options()}")
    ensure
      forward_cmd_results?(original_fwd_state)
    end
  end
  
  # A wrapper for running another Tungsten script on a remote host. This will 
  # automatically forward messages to the console and add any TungstenScript 
  # options to the command.
  def tungsten_ssh_result(command, host, user)
    # Run the command outside of SSH if possible
    if is_localhost?(host) && 
        user == whoami()
      return tungsten_cmd_result(command)
    end
    
    original_fwd_state = forward_cmd_results?()
    begin
      if TI
        prefix = "export CONTINUENT_ROOT=#{TI.root()}; "
      else
        prefix = ""
      end
      
      forward_cmd_results?(true)
      return ssh_result("#{prefix}#{command} #{get_tungsten_command_options()}", host, user)
    ensure
      forward_cmd_results?(original_fwd_state)
    end
  end
  
  # Run the {command} and return a string of STDOUT
  def cmd(command, ignore_fail = false, stdin_method = nil, stdout_method = nil, stderr_method = nil)
    errors = ""
    result = ""
    threads = []
    
    debug("Execute `#{command}`")
    status = Open4::popen4("export LANG=en_US; #{command}") do |pid, stdin, stdout, stderr|
      if stdin_method != nil
        threads << Thread.new{
          stdin_method.call(stdin)
          stdin.close
        }
      else
        stdin.close
      end
      
      threads << Thread.new{
        while data = stdout.gets()
          if data.to_s() != ""
            result+=data
            
            if data != "" && forward_cmd_results?()
              write(data, (parse_log_level(data) || get_forward_log_level()), nil, false)
            end
            
            if stdout_method != nil
              stdout_method.call(data)
            end
          end
        end
      }
      threads << Thread.new{
        while edata = stderr.gets()
          if edata.to_s() != ""
            errors+=edata
            
            if edata != "" && forward_cmd_results?()
              write(edata, (parse_log_level(edata) || get_forward_log_level()), nil, false)
            end

            if stderr_method != nil
              stderr_method.call(edata)
            end
          end
        end
      }
      
      threads.each{|t| t.join() }
    end
    
    result.strip!()
    errors.strip!()
    
    original_errors = errors
    rc = status.exitstatus
    if errors == ""
      errors = "No STDERR"
    else
      errors = "Errors: #{errors}"
    end

    if log_cmd_results?()
      debug("RC: #{rc}, Result: #{result}, #{errors}")
    elsif forward_cmd_results?()
      debug("RC: #{rc}, Result length #{result.length}, Errors length #{original_errors.length}")
    else
      debug("RC: #{rc}, Result length #{result.length}, #{errors}")
    end
    if rc != 0 && ! ignore_fail
      raise CommandError.new(command, rc, result, original_errors)
    end

    return result
  end
end

module TungstenScript
  alias orig_validate validate
  
  def validate
    orig_validate()
  end
end

class Array
  def peach(&block)
    threads = []
    
    self.each{
      |i|
      threads << Thread.new(i) {
        |member|
        block.call(member)
      }
    }
    
    threads.each{|t| t.join() }
    self
  end
end