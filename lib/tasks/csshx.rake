def csshx(private_chef_config, repo_dir)
  require_relative '../../cookbooks/ec-common/libraries/topo_helper'

  hosts = []

  keydir = File.join(repo_dir, 'keys')

  topo = TopoHelper.new(ec_config: private_chef_config['layout'])
  topo.merged_topology.each do |node, attrs|
    hosts << attrs['ipaddress']
  end

  case private_chef_config['provider']
  when 'ec2'
    ssh_username = private_chef_config['ec2_options']['ssh_username'] || 'ec2-user'
  when 'vagrant'
    ssh_username = 'vagrant'
  else
    ssh_username = 'root'
  end

  sh("csshx #{hosts.join(' ')} -l #{ssh_username} --ssh_args '-i #{keydir}/id_rsa'")
  if RUBY_PLATFORM =~ /darwin/
    %x{osascript -e 'tell application "Terminal" to activate'}
  end
end

def get_config
  JSON.parse(File.read(ENV['ECM_CONFIG'] || 'config.json'))
end

harness_dir = ENV['HARNESS_DIR'] ||= File.dirname(__FILE__)
repo_dir = ENV['REPO_PATH'] ||= File.join(harness_dir, 'chef-repo')

desc "Open csshx to the nodes of the server."
task :csshx do
  config = get_config
  config = fog_populate_ips(config) if config['provider'] == 'ec2'
  csshx(config, repo_dir)
end