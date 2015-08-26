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
  # Override the method imported from tpm to include '>>' to avoid detecting
  # an error that wasn't thrown by TungstenScript
  def parse_log_level(line)
    prefix = line[0,8]
    
    case prefix.strip
    when "ERROR >>" then Logger::ERROR
    when "WARN  >>" then Logger::WARN
    when "DEBUG >>" then Logger::DEBUG
    when "NOTE  >>" then Logger::NOTICE
    when "INFO  >>" then Logger::INFO
    else
      nil
    end
  end
  
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
  
  def scp_result(local_file, remote_file, host, user)
    unless File.file?(local_file)
      debug("Unable to copy '#{local_file}' because it doesn't exist")
      raise MessageError.new("Unable to copy '#{local_file}' because it doesn't exist")
    end

    if is_localhost?(host) && 
        user == whoami()
      debug("Copy #{local_file} to #{remote_file}")
      return FileUtils.cp(local_file, remote_file)
    end

    self.synchronize() {
      unless defined?(Net::SCP)
        begin
          require "openssl"
        rescue LoadError
          raise("Unable to find the Ruby openssl library. Try installing the openssl package for your version of Ruby (libopenssl-ruby#{RUBY_VERSION[0,3]}).")
        end
        require 'net/scp'
      end
    }

    ssh_user = get_ssh_user(user)
    if user != ssh_user
      debug("SCP user changed to #{ssh_user}")
    end

    connection_error = "Net::SCP was unable to copy #{local_file} to #{host}:#{remote_file} as #{ssh_user}.  Check that #{host} is online, #{ssh_user} exists and your SSH private keyfile or ssh-agent settings. Try adding --net-ssh-option=port=<SSH port number> if you are using an SSH port other than 22.  Review http://docs.continuent.com/helpwithsshandtpm for more help on diagnosing SSH problems."
    debug("Copy #{local_file} to #{host}:#{remote_file} as #{ssh_user}")
    begin
      Net::SCP.start(host, ssh_user, get_ssh_options) do |scp|
        scp.upload!(local_file, remote_file, get_ssh_options)
      end

      if user != ssh_user
        ssh_result("sudo -n chown -R #{user} #{remote_file}", host, ssh_user)
      end

      return true
    rescue Errno::ENOENT => ee
      raise MessageError.new("Net::SCP was unable to find a private key to use for SSH authenticaton. Try creating a private keyfile or setting up ssh-agent.")
    rescue OpenSSL::PKey::RSAError
      raise MessageError.new(connection_error)
    rescue Net::SSH::AuthenticationFailed
      raise MessageError.new(connection_error)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      raise MessageError.new(connection_error)
    rescue Timeout::Error
      raise MessageError.new(connection_error)
    rescue Exception => e
      raise RemoteCommandError.new(user, host, "scp #{local_file} #{ssh_user}@#{host}:#{remote_file}", nil, '')
    end
  end
  
  def scp_download(remote_file, local_file, host, user)
    if is_localhost?(host) && user == whoami()
      debug("Copy #{remote_file} to #{local_file}")
      return FileUtils.cp(remote_file, local_file)
    end

    begin
      exists = ssh_result("if [ -f #{remote_file} ]; then echo 0; else echo 1; fi", host, user)
      if exists == "1"
        raise MessageError.new("Unable to download '#{remote_file}' because the file does not exist on #{host}")
      end
    rescue CommandError
      raise MessageError.new("Unable to check if '#{remote_file}' exists on #{host}")
    end

    self.synchronize() {
      unless defined?(Net::SCP)
        begin
          require "openssl"
        rescue LoadError
          raise("Unable to find the Ruby openssl library. Try installing the openssl package for your version of Ruby (libopenssl-ruby#{RUBY_VERSION[0,3]}).")
        end
        require 'net/scp'
      end
    }

    ssh_user = get_ssh_user(user)
    if user != ssh_user
      debug("SCP user changed to #{ssh_user}")
    end

    connection_error = "Net::SCP was unable to copy to #{host}:#{remote_file} #{local_file} as #{ssh_user}.  Check that #{host} is online, #{ssh_user} exists and your SSH private keyfile or ssh-agent settings. Try adding --net-ssh-option=port=<SSH port number> if you are using an SSH port other than 22.  Review http://docs.continuent.com/helpwithsshandtpm for more help on diagnosing SSH problems."
    debug("Copy #{host}:#{remote_file} to #{local_file} as #{ssh_user}")
    begin
      Net::SCP.download!(host, ssh_user, remote_file, local_file, get_ssh_options)

      return true
    rescue Errno::ENOENT => ee
      raise MessageError.new("Net::SCP was unable to find a private key to use for SSH authenticaton. Try creating a private keyfile or setting up ssh-agent.")
    rescue OpenSSL::PKey::RSAError
      raise MessageError.new(connection_error)
    rescue Net::SSH::AuthenticationFailed
      raise MessageError.new(connection_error)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      raise MessageError.new(connection_error)
    rescue Timeout::Error
      raise MessageError.new(connection_error)
    rescue Exception => e
      raise RemoteCommandError.new(user, host, "scp #{ssh_user}@#{host}:#{remote_file} #{local_file}", nil, '')
    end
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