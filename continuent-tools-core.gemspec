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

Gem::Specification.new do |s|
  s.name        = 'continuent-tools-core'
  s.version     = '0.12.0'
  s.date        = Date.today.to_s
  s.summary     = "Continuent Tungsten tools core functions"
  s.authors     = ["Continuent"]
  s.email       = 'info@continuent.com'
  s.files       = Dir.glob("{bin,lib,providers}/**/*") + %w(LICENSE README.md)
  Dir.glob("bin/*").each{|bin|
    s.executables << File.basename(bin)
  }
  s.homepage    =
    'https://github.com/continuent/continuent-tools-core'
  s.license       = 'Apache-2.0'
  s.add_runtime_dependency 'json_pure'
  s.add_runtime_dependency 'net-ssh', '<=2.9.2'
  s.add_runtime_dependency 'net-scp'
  s.add_runtime_dependency 'xhr-ifconfig'
  s.add_runtime_dependency 'escape'
  s.add_runtime_dependency 'zip'
  s.add_runtime_dependency 'open4'
end