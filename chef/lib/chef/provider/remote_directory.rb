#
# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/provider/file'
require 'chef/provider/directory'
require 'chef/rest'
require 'chef/resource/directory'
require 'chef/resource/remote_file'
require 'chef/platform'
require 'uri'
require 'tempfile'
require 'net/https'

class Chef
  class Provider
    class RemoteDirectory < Chef::Provider::Directory
      
      def action_create
        super

        @remote_file_list = Hash.new
        do_recursive
      end
    
      def action_create_if_missing
        raise Chef::Exception::UnsupportedAction, "Remote Directories do not support create_if_missing."
      end
    
      def do_recursive
        Chef::Log.debug("Doing a recursive directory transfer for #{@new_resource}")
      
        r = Chef::REST.new(Chef::Config[:remotefile_url])
      
        files_to_transfer = r.get_rest(generate_url(@new_resource.source, "files", { :recursive => "true" }))
      
        files_to_transfer.each do |remote_file_source|
          full_path = ::File.join(@new_resource.path, remote_file_source)
          full_dir = ::File.dirname(full_path)
          unless ::File.directory?(full_dir)
            new_dir = Chef::Resource::Directory.new(full_dir, nil, @node)
            new_dir.cookbook_name = @new_resource.cookbook || @new_resource.cookbook_name            
            new_dir.mode(@new_resource.mode)
            new_dir.group(@new_resource.group)
            new_dir.owner(@new_resource.owner)
            new_dir.recursive(true)
            
            d_provider_class = Chef::Platform.find_provider_for_node(@node, new_dir)
            d_provider = d_provider_class.new(@node, new_dir)
            d_provider.load_current_resource
            d_provider.action_create
            @new_resource.updated = true if d_provider.new_resource.updated
          end
          
          remote_file = Chef::Resource::RemoteFile.new(full_path, nil, @node)
          remote_file.cookbook_name = @new_resource.cookbook || @new_resource.cookbook_name           
          remote_file.source(::File.join(@new_resource.source, remote_file_source))
          remote_file.mode(@new_resource.files_mode) if @new_resource.files_mode
          remote_file.group(@new_resource.files_group) if @new_resource.files_group
          remote_file.owner(@new_resource.files_owner) if @new_resource.files_owner
          remote_file.backup(@new_resource.files_backup) if @new_resource.files_backup
          
          rf_provider_class = Chef::Platform.find_provider_for_node(@node, remote_file)
          rf_provider = rf_provider_class.new(@node, remote_file)          
          rf_provider.load_current_resource
          rf_provider.action_create
          @new_resource.updated = true if rf_provider.new_resource.updated
        end
      end
      
    end
  end
end