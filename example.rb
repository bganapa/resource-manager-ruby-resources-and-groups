#!/usr/bin/env ruby

require 'azure_mgmt_resources'
require 'dotenv'

Dotenv.load!(File.join(__dir__, './.env'))

LOCATION = 'shanghai'
GROUP_NAME = 'azure-sample-group'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

# Manage resources and resource groups - create, update and delete a resource group, deploy a solution into a resource
#   group, export an ARM template. Create, read, update and delete a resource
#
# This script expects that the following environment vars are set:
#
# AZURE_TENANT_ID: with your Azure Active Directory tenant id or domain
# AZURE_CLIENT_ID: with your Azure Active Directory Application Client ID
# AZURE_CLIENT_SECRET: with your Azure Active Directory Application Secret
# AZURE_SUBSCRIPTION_ID: with your Azure Subscription Id
#
def run_example
  #
  # Create the Resource Manager Client with an Application (service principal) token provider
  #
  subscription_id = ENV['AZURE_SUBSCRIPTION_ID'] || '11111111-1111-1111-1111-111111111111' # your Azure Subscription Id
  environment_settings = get_environment_settings('AzureStack')

  provider = MsRestAzure::ApplicationTokenProvider.new(
      ENV['AZURE_TENANT_ID'],
      ENV['AZURE_CLIENT_ID'],
      ENV['AZURE_CLIENT_SECRET'],
      environment_settings)

  credentials = MsRest::TokenCredentials.new(provider)
  
  options = {
      credentials: credentials,
      subscription_id: subscription_id,
      environment_settings: environment_settings
  }

  client = Azure::Resources::Profiles::V2017_03_09::Mgmt::Client.new(options)

  #
  # Managing resource groups
  #
  resource_group_params = client.model_classes.resource_group.new.tap do |rg|
    rg.location = LOCATION
  end

  # List Resource Groups
  puts 'List Resource Groups'
  client.resource_groups.list.each{ |group| print_item(group) }

  # Create Resource group
  puts 'Create Resource Group'
  print_item client.resource_groups.create_or_update(GROUP_NAME, resource_group_params)

  # Modify the Resource group
  puts 'Modify Resource Group'
  resource_group_params.tags = { hello: 'world' }
  print_item client.resource_groups.create_or_update(GROUP_NAME, resource_group_params)

  # Create a Key Vault in the Resource Group
  puts 'Create a Key Vault via a Generic Resource Put'
  key_vault_params = client.model_classes.generic_resource.new.tap do |rg|
    rg.location = LOCATION
    rg.properties = {
        sku: { family: 'A', name: 'standard' },
        tenantId: ENV['AZURE_TENANT_ID'],
        accessPolicies: [],
        enabledForDeployment: true,
        enabledForTemplateDeployment: true,
        enabledForDiskEncryption: true
    }
  end
  puts JSON.pretty_generate(client.resources.create_or_update(GROUP_NAME,
                                         'Microsoft.KeyVault',
                                         '',
                                         'vaults',
                                         'azureSampleVault',
                                         '2015-06-01',
                                         key_vault_params).properties)  + "\n\n"

  # List Resources within the group
  puts 'List all of the resources within the group'
  #client.resource_groups.list.each{ |resource| print_item(resource) }
  client.resources.list.each{ |resource| print_item(resource)}

  # Export the Resource group template
  puts 'Export Resource Group Template'
  export_params = client.model_classes.export_template_request.new.tap do |rg|
    rg.resources = ['*']
  end
  puts JSON.pretty_generate(client.resource_groups.export_template(GROUP_NAME, export_params).template) + "\n\n"

  # Delete Resource group and everything in it
  puts 'Delete Resource Group'
  client.resource_groups.delete(GROUP_NAME)
  puts "\nDeleted: #{GROUP_NAME}"

end

def print_item(group)
  puts "\tName: #{group.name}"
  puts "\tId: #{group.id}"
  puts "\tLocation: #{group.location}"
  puts "\tTags: #{group.tags}"
  print_properties(group.properties)
end

def print_properties(props)
  puts "\tProperties:"
  props.instance_variables.sort.each do |ivar|
    str = ivar.to_s.gsub /^@/, ''
    if props.respond_to? str.to_sym
      puts "\t\t#{str}: #{props.send(str.to_sym)}"
    end
  end
  puts "\n\n"
end


def get_environment_settings(name)
    settings=MsRestAzure::AzureEnvironments::AzureEnvironment.new({
                                                    :name => 'AzureStack',
                                                    :portal_url => 'http://go.microsoft.com/fwlink/?LinkId=254433',
                                                    :management_endpoint_url => 'https://management.core.windows.net',
                                                    :resource_manager_endpoint_url => 'https://management.shanghai.azurestack.corp.microsoft.com/',
                                                    :active_directory_endpoint_url => 'https://login.windows.net/',
                                                    :authentication_endpoint => 'https://login.windows.net/',
                                                    :token_audience => 'https://management.masselfhost.onmicrosoft.com/08845a35-a6fe-4462-b56f-c00829e32e77',
                                                    :active_directory_resource_id => 'https://management.masselfhost.onmicrosoft.com/08845a35-a6fe-4462-b56f-c00829e32e77',
                                                    :active_directory_graph_resource_id => 'https://graph.windows.net/',
                                                    :storage_endpoint_suffix => '.shanghai.azurestack.corp.microsoft.com',
                                                    :key_vault_dns_suffix => '.vault.shanghai.azurestack.corp.microsoft.com'
                                                })
    settings
end



if $0 == __FILE__
  run_example
end


