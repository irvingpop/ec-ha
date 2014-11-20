# encoding: utf-8

require 'chef/resource/lwrp_base'

class Chef
  class Resource
    class Ec11Users < Chef::Resource::LWRPBase
      self.resource_name = :ec11_users
      actions :create
      default_action :create
    end
  end
end

require 'chef/provider/lwrp_base'

class Chef
  class Provider
    class Ec11Users < Chef::Provider::LWRPBase
      use_inline_resources

      # from patrick-wright/ec-tools::knife-opc
      knife_opc_cmd = '/opt/opscode/embedded/bin/knife-opc'

      user_root = '/srv/piab/users'
      sentinel_file = '/srv/piab/dev_users_created'
      organizations = {
        'ponyville' => [
            'rainbowdash',
            'fluttershy',
            'applejack',
            'pinkiepie',
            'twilightsparkle',
            'rarity'
        ],
        'wonderbolts' => [
            'spitfire',
            'soarin',
            'rapidfire',
            'fleetfoot'
        ]
      }

      action :create do
        domainname = TopoHelper.new(ec_config: node['private-chef']).mydomainname

        directory user_root do
          action :create
          recursive true
        end

        create_orgs_and_users(organizations, user_root, knife_opc_cmd, domainname)

        file sentinel_file do
          content "Canned dev users and organization created successfully at #{::Time.now}"
          action :create
        end
      end

      def create_orgs_and_users(organizations, user_root, knife_opc_cmd, domainname)
        organizations.each do |orgname, users|
          execute "create_org_#{orgname}" do
            command "#{knife_opc_cmd} org create #{orgname} #{orgname} -f #{user_root}/#{orgname}-validator.pem"
            creates "/tmp/something"
            action :run
          end

          users.each do |username|
            folder = "#{user_root}/#{username}"
            dot_chef = "#{folder}/.chef"

            directory dot_chef do
              action :create
              recursive true
            end

            # create a knife.rb file for the user
            template "#{dot_chef}/knife.rb" do
              source "knife.rb.erb"
              variables(
                :username => username,
                :orgname => orgname,
                :server_fqdn => "api.#{domainname}"
              )
              mode "0777"
              action :create
            end

            execute "create_user_#{username}_in_org_#{orgname}" do
              # it goes USERNAME FIRST_NAME [MIDDLE_NAME] LAST_NAME EMAIL PASSWORD options
              cmd_args = [
                          knife_opc_cmd, 'user', 'create',
                          username, username, username,
                          "#{username}@#{orgname}.org",
                          username,
                          '-o', orgname,
                          '-f' "#{dot_chef}/#{username}.pem"
                         ]
              command cmd_args.join(' ')
              action :run
            end
          end
        end
      end

    end
  end
end