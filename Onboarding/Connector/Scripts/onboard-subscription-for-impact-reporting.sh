#!/bin/bash

# USAGE : Please refer deploy-cas-help.txt

# Running in debug mode
# Uncomment to enable debug mode. Make sure you also uncomment set +x in the end of the script.
# Please DO NOT COMMIT UNCOMMENTED DEBUG FLAG. This would fail the CDPx build as it treats the debug output as stderr.

set -x
set -e

print_help () 
{
    log -e "\n"
    echo "# # ############ USAGE ############ #"
    echo "#"
    echo "# onboard-subscription-for-impact-reporting.sh"
    echo "#            --subscription-id <The subscription id of the subscription that is getting onboarded to ImpactRP>"
    echo "#            --file-path <The file path where newline separated list of subscriptions is present>"
    echo "#            --help <Print this help page>"
    echo "# "
    echo "# This script is used to onboard subscription(s) to ImpactRP."
    echo "#"
    echo "# # ############ ##### ############ #"

    log -e "\n"
}

create_custom_role_json_file () 
{
    subscription_id=$1
    role_name=$2
    file_name=$3

    echo "{\
        \"Name\": \"$role_name\",\
        \"IsCustom\": true,\
        \"Description\": \"Allows for reading alerts.\",\
        \"Actions\": [\
          \"Microsoft.AlertsManagement/alerts/read\"\
        ],\
        \"AssignableScopes\": [\
            \"/subscriptions/$subscription_id\"\
          ]\
      }" > "$file_name"
}

log ()
{
    date=$(date)
    msg=$1
    echo "$date - $msg" >&2
}

az_login_with_prompt()
{
    subscription_id=$1
    
    if ! az account show ; then
      log "Login to Azure"
    	az login
    fi

    log "Setting Azure subscription as $subscription_id"
    az account set --subscription "$subscription_id"
}

register_namespace(){
  namespace=$1

  log "Registering namespace - $namespace" 
  
  az provider register -n "$namespace"

  verify_namespace_registration "$namespace"
  log "Successfully registered namespace - $namespace" 
}

verify_namespace_registration(){
  namespace=$1

  log "Verifying registration for namespace $namespace, namespace registration can take upto several minutes " 
  registration_status=""
  attempt_count=1
  sleep_duration=10
  while [ "$registration_status" != "Registered" ] 
  do
    log "Attempt #$attempt_count: Verifying registration status for namespace - $namespace"
    registration_status=$(az provider show -n "$namespace" | jq -r ".registrationState")
    sleep_duration=$((sleep_duration*2))
    log "Attempt #$attempt_count: Waiting for $sleep_duration seconds before retrying."
    sleep "$sleep_duration"
    attempt_count=$((attempt_count+1))
  done
  log "Registration of namespace - $namespace is successful" 
}

register_feature(){
  namespace=$1
  feature_name=$2

  registration_status=$(az feature register --name "$feature_name" --namespace "$namespace" | jq -r .properties.state)

  if [ "$registration_status" != "Registered" ]; then
    log "Started registration of feature - $feature_name in namespace - $namespace" 
    verify_feature_registration "$namespace" "$feature_name"
    log "Successfully registered feature - $feature_name in namespace - $namespace" 
  else
    log "Feature $feature_name in namespace $namespace is already registered"
  fi

  log "Getting the changes for the feature $feature_name in namespace $namespace propogated to the subscription"
  register_namespace "$namespace"
  log "Changes for the feature $feature_name in namespace $namespace are propogated to the subscription"
}

verify_feature_registration(){
  namespace=$1
  feature_name=$2

  log "Verifying registration for feature: $feature_name in namespace $namespace, feature registration can take upto several minutes " 
  registration_status=""
  attempt_count=1
  sleep_duration=10
  while [ "$registration_status" != "Registered" ] 
  do
    log "Attempt #$attempt_count: Verifying registration status for $feature_name in namespace $namespace"
    registration_status=$(az feature list -o json --query "[?contains(name, '$namespace/$feature_name')].{Name:name,State:properties.state}" | jq -r ".[] | select(.Name == \"$namespace/$feature_name\").State")
    sleep_duration=$((sleep_duration*2))
    log "Attempt #$attempt_count: Waiting for $sleep_duration seconds before retrying."
    sleep "$sleep_duration"
    attempt_count=$((attempt_count+1))
  done
}

setup_permissions_for_alerts_reading()
{
  subscription_id=$1
  log "Setting up permissions for alerts reading" 
  role_name="Azure-Alerts-Reader-Role"
  connector_app_name="AzureImpactReportingConnector"

  role_id=$(az role definition list -n "$role_name"  --query [].id -o tsv)
  if [ ! "$role_id" ]; then
    log "Creating custom role for alerts reading."
    
    custom_role_json_file="/tmp/custom-role.json"
    create_custom_role_json_file "$subscription_id" "$role_name" "$custom_role_json_file"
    role_id=$(az role definition create --role-definition "$custom_role_json_file" | jq -r ".id")
    rm -rf "$custom_role_json_file"
    
    log "Custom role: $role_name for alerts reading created successfully with role id: $role_id."
  else
    log "Custom role: $role_name for alerts reading already exists with role id: $role_id."
  fi
  
  log "Assigning the custom role: $role_name to the connector app: $connector_app_name"
  connector_principal_id=$(az ad sp list --display-name "$connector_app_name" --query "[].id" -o tsv)

  assigned_custom_role=$(az role assignment list --assignee "$connector_principal_id" --role "$role_id" --query [].id -o tsv)

  if [ ! "$assigned_custom_role" ]; then
    az role assignment create --role "$role_id" --assignee-object-id "$connector_principal_id" --scope "/subscriptions/$subscription_id"
    log "Custom role: $role_name assigned to the connector app: $connector_app_name"
  else
    log "Custom role: $role_name already assigned to the connector app: $connector_app_name"
  fi

  log "Successfully setup permissions for alerts reading" 
}

deploy_connector()
{
  subscription_id=$1
  connector_name="AzureMonitorConnector"
  log "Deploying connector: $connector_name for impact reporting" 

  request_body="{
      \"properties\": \
          {\"connectorType\": \"AzureMonitor\"\
      }\
    }"
  url="https://management.azure.com/subscriptions/$subscription_id/providers/Microsoft.Impact/connectors/$connector_name?api-version=2024-05-01-preview"

  attempt_count=1
  sleep_duration=10

  while ! az rest --method put --url "$url" --body "$request_body" --query "properties.provisioningState" | grep -q "Succeeded"; do
    sleep_duration=$((sleep_duration*2))
    log "Attempt #$attempt_count: Connector deployment is in progress. Waiting for $sleep_duration seconds before retrying."
    sleep "$sleep_duration"
    attempt_count=$((attempt_count+1))
  done 

  log "Deployment of connector: $connector_name is complete" 
}

validate_input()
{
  [[ -z "$subscription_id" && -z "$file_path" ]] && (log "Please provided required input: subscription_id or file_path with list of subscription IDs while invoking the script" && exit 1)
  [[ -n "$subscription_id" && -n "$file_path" ]] && (log "Please provided either subscription_id or file_path with list of subscription IDs while invoking the script. Do not provide both." && exit 1)

  [[ -n "$subscription_id" ]] && (log "Using Subscription ID = $subscription_id")
  
  if [[ -n "$file_path" ]]; then
    log "Subscription IDs will be read from the file: $file_path"
    if [[ ! -f "$file_path" ]]; then
      log "Failed to find file: $file_path. Please provide a valid file path that you have access to" && exit 1
    fi
  fi

  log "==== All required inputs are present ===="
}

enable_impact_reporting()
{
  log "==== Enabling impact reporting ===="
  
  # Check if the file is given and exists
  if [ -n "$file_path" ] && [ -f "$file_path" ]; then
      # Read the file into an array
      mapfile -t subscription_ids < "$file_path"
  else
      # Create an array with a single element
      subscription_ids=("$subscription_id")
  fi

  # Print the array
  for item in "${subscription_ids[@]}"; do
      az_login_with_prompt "$item"
      register_feature "Microsoft.Impact" "AzureImpactReportingConnector"
      register_feature "Microsoft.Impact" "AllowImpactReporting"
      setup_permissions_for_alerts_reading "$item"
      deploy_connector "$item"
      log "==== Impact reporting is now enabled on your subscription: $item!! ===="
  done
}

main()
{
  while [[ $# -gt 0 ]]; do
    opt="$1"
    shift;
    case "$opt" in
      "--help"                                    ) print_help; exit;;
      "--subscription-id"                        	) subscription_id="$1"; shift;;
      "--file-path"                           	  ) file_path="$1"; shift;;
      *                                           ) echo "ERROR: Invalid option: \"$opt\"" >&2 && print_help && exit 1;;
    esac
  done
  
  validate_input
  enable_impact_reporting
}

main "$@"