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

# Extract the required libraries from 
# https://code.google.com/p/tungsten-replicator/
`#{File.dirname(__FILE__)}/export-from-trunk.sh`

Gem::Specification.new do |s|
  s.name        = 'continuent-tools-core'
  s.version     = '0.0.1'
  s.date        = '2014-02-24'
  s.summary     = "Continuent Tools core functions"
  s.authors     = ["Continuent"]
  s.email       = 'info@continuent.com'
  s.files       = Dir.glob("{bin,lib}/**/*") + %w(LICENSE README.md)
  s.homepage    =
    'https://github.com/continuent/continuent-tools-core'
  s.license       = 'Apache-2.0'
  s.add_runtime_dependency 'json'
  s.add_runtime_dependency 'net-ssh'
  s.add_runtime_dependency 'net-scp'
  s.add_runtime_dependency 'xhr-ifconfig'
  s.add_runtime_dependency 'escape'
  s.add_runtime_dependency 'zip'
  s.add_runtime_dependency 'open4'
end