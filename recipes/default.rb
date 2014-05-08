#
# Cookbook Name:: tomcat-any-ver
# Recipe:: default
#
# Copyright 2013, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#


include_recipe "java"

# Determine version
version = node['tomcat-any-ver']['version']
base_version = version.split('.')[0]
base_name = "tomcat#{base_version}"
qualified_name = "apache-tomcat-#{version}"

log "Installing #{base_name} with specific version: #{version}"

# Create user and group
group "#{base_name}" do
end
user "#{base_name}" do
  gid "#{base_name}"
end

# Define default paths
bin_base_path = "/usr/share"
bin_path   = "#{bin_base_path}/#{base_name}"
var_path   = "/var/lib/#{base_name}"
log_path   = "/var/log/#{base_name}"
cache_path = "/var/cache/#{base_name}"
conf_path  = "/etc/#{base_name}"

# Download tomcat package and untar
log "Downloading #{qualified_name}.tar.gz to #{Chef::Config[:file_cache_path]}"
remote_file "#{Chef::Config[:file_cache_path]}/#{qualified_name}.tar.gz" do
  source "http://archive.apache.org/dist/tomcat/tomcat-#{base_version}/v#{version}/bin/#{qualified_name}.tar.gz"
end
execute "tar" do
  cwd "#{Chef::Config[:file_cache_path]}"
  command "tar xzvf #{Chef::Config[:file_cache_path]}/#{qualified_name}.tar.gz"
end


# Place all resourced around the file system
src_dir = "#{Chef::Config[:file_cache_path]}/#{qualified_name}"

  # bin, lib - resources
directory "#{bin_base_path}/#{qualified_name}" do
  owner "root"
  group "root"
end
bash "bin_resources" do
  code <<-EOL
  cp -r #{src_dir}/bin #{bin_base_path}/#{qualified_name}/
  cp -r  #{src_dir}/lib #{bin_base_path}/#{qualified_name}/
  EOL
  not_if { ::Dir.exists?("#{bin_base_path}/#{qualified_name}/bin") or ::Dir.exists?("#{bin_base_path}/#{qualified_name}/lib") }
end
link "#{bin_path}" do
  to "#{bin_base_path}/#{qualified_name}"
end

  # var - resources
directory "#{var_path}" do
  owner "root"
  group "root"
end

remote_directory "#{var_path}/webapps" do
  source "webapps"
  owner "#{base_name}"
  group "#{base_name}"
  files_owner "#{base_name}"
  files_group "#{base_name}"
  recursive true
end

directory "#{log_path}" do
  owner "#{base_name}"
  group "#{base_name}"
end
link "#{var_path}/logs" do
  to "#{log_path}"
end

directory "#{cache_path}" do
  owner "#{base_name}"
  group "#{base_name}"
end
link "#{var_path}/work" do
  to "#{cache_path}"
end


  # conf - resources
directory "#{conf_path}" do
  owner "#{base_name}"
  group "#{base_name}"
end
link "#{var_path}/conf" do
  to "#{conf_path}"
end
bash "conf_resources" do
  code <<-EOL
  cp -r #{src_dir}/conf/* #{conf_path}
  chown -R root:#{base_name} #{conf_path}
  chmod -R 0644 #{conf_path}
  chown root:root #{conf_path}
  chmod 0755 #{conf_path}
  EOL
  not_if { ::File.exists?("#{conf_path}/catalina.properties") }
end
remote_directory "#{conf_path}/Catalina" do 
  source "Catalina"
  owner "root"
  group "root"
  files_owner "root"
  files_group "root"
  recursive true
end

# Create service runner
template "/etc/init.d/#{base_name}" do
  source "service.erb"
  owner "root"
  group "root"
  mode "0755"
  variables ({
    :base_version => base_version
  })
end

# Create file where default variables are set
template "/etc/default/#{base_name}" do
  source "default.tomcat.erb"
  owner "root"
  group "root"
  mode "0644"
  variables ({
    :base_version => base_version,
    :java_home => node['tomcat-any-ver']['java_home']
  })
end

# Start service
service "#{base_name}" do
  action :start
end
