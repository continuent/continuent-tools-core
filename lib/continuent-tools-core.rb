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
end