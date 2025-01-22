#!/bin/bash

# Running in debug mode
# Uncomment to enable debug mode. Make sure you also uncomment set +x in the end of the script.
# Please DO NOT COMMIT UNCOMMENTED DEBUG FLAG.

# set -x
set -e

# Text Styles
BOLD="\e[1m"
RESET="\e[0m"
# Foreground Colors
BLACK="\e[30m"
# Background Colors
WHITE_BG="\e[47m"

IMPACT_REPORTER_ROLE_NAME="Impact Reporter"
MONITORING_READER_ROLE_NAME="Monitoring Reader"
APP_REGISTRATION_NAME="DynatraceImpactReportingConnectorApp"
APP_SECRET_NAME="DynatraceOnboardingSecret"
APP_SECRET_VALUE=""

print_help () 
{
    log -e "\n"
    echo "# # ############ USAGE ############ #"
    echo "#"
    echo "# azure-impact-reporting-onboarding.sh"
    echo "#            --subscription-id <The subscription id of the subscription for onboarding to impact reporting.>"
    echo "#            --file-path <The file path where newline separated list of subscriptions for onboarding to impact reporting.>"
    echo "#            --app-id <(Optional, not recommended) The app id of the existing app registration to be used for role assignment and secret generation. If not provided, a new app registration will be created.>"
    echo "#            --help <Print this help page>"
    echo "# "
    echo "# This script is used to set-up pre-requisites and onboard one or more subscriptions for Azure Impact Reporting. It does the following:"
    echo "# 1. Creates a new Entra App, otherwise uses an existing one."
    echo "# 2. Registers the preview feature AllowImpactReporting in subscriptions considered for onboarding."
    echo "# 3. Registers the resource provider Microsoft.Impact in subscriptions considered for onboarding."
    echo "# 4. Optionally, if consented, generates a secret to complete onboarding."
    echo "#"
    echo "# Note: This script takes ~20 minutes to complete execution."
    echo "# # ############ ##### ############ #"

    log -e "\n"
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

validate_input()
{
  [[ -z "$subscription_id" && -z "$file_path" ]] && (log "Please provide required input: subscription_id or file_path with list of subscription IDs while invoking the script" && exit 1)
  [[ -n "$subscription_id" && -n "$file_path" ]] && (log "Please provide either subscription_id or file_path with list of subscription IDs while invoking the script. Do not provide both." && exit 1)

  [[ -n "$subscription_id" ]] && (log "Using Subscription ID = $subscription_id")
  
  if [[ -n "$file_path" ]]; then
    if [[ ! -f "$file_path" ]]; then
      log "Failed to find file: $file_path. Please provide a valid file path that you have access to" && exit 1
    fi
    log "Subscription IDs will be read from the file: $file_path"
  fi

  if [[ "$use_existing_app" = true ]]; then
    [[ -z "$app_id" ]] && (log "Optional input app-id can not be empty. Consider running the script without --app-id, if you do not want to use an existing app registration." && exit 1)
    
    # Check if the app_id is valid. Error is thrown if the app_id is invalid.
    app_id=$(az ad app show --id $app_id --query appId --output tsv)
    log "Using App ID: $app_id"
  fi

  log "==== All required inputs are present ===="
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
  registration_status=$(az provider show -n "$namespace" | jq -r ".registrationState")
  attempt_count=1
  sleep_duration=60
  while [ "$registration_status" != "Registered" ] 
  do
    log "Attempt #$attempt_count: Waiting for $sleep_duration seconds before retrying."
    sleep "$sleep_duration"
    attempt_count=$((attempt_count+1))
    log "Attempt #$attempt_count: Verifying registration status for namespace - $namespace"
    registration_status=$(az provider show -n "$namespace" | jq -r ".registrationState")
    log "Registration status: $registration_status"
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
  registration_status=$(az feature list -o json --query "[?contains(name, '$namespace/$feature_name')].{Name:name,State:properties.state}" | jq -r ".[] | select(.Name == \"$namespace/$feature_name\").State")
  attempt_count=1
  sleep_duration=60
  while [ "$registration_status" != "Registered" ] 
  do
    log "Attempt #$attempt_count: Waiting for $sleep_duration seconds before retrying."
    sleep "$sleep_duration"
    attempt_count=$((attempt_count+1))
    log "Attempt #$attempt_count: Verifying registration status for $feature_name in namespace $namespace"
    registration_status=$(az feature list -o json --query "[?contains(name, '$namespace/$feature_name')].{Name:name,State:properties.state}" | jq -r ".[] | select(.Name == \"$namespace/$feature_name\").State")
    log "Registration status: $registration_status"
  done
}

setup_required_permissions()
{
  subscription_id=$1
  log "Setting up permissions for impact reporting and monitoring reader" 
  log "Assigning the Role: $IMPACT_REPORTER_ROLE_NAME to the app with Id: $app_id"

  principal_id=$(az ad sp list --filter "appId eq '$app_id'" --query "[].id" --output tsv)
  if [ -z "$principal_id" ]; then
    log "Service principal does not exist. Creating service principal for the app with Id: $app_id"
    principal_id=$(az ad sp create --id "$app_id" --query id --output tsv)
    log "Service principal with Id: $principal_id created successfully for the app with Id: $app_id"
  else
    log "Service principal with Id: $principal_id already exists for the app with Id: $app_id"
  fi

  if ! has_role_assignment "$principal_id" "$IMPACT_REPORTER_ROLE_NAME"; then
    az role assignment create --role "$IMPACT_REPORTER_ROLE_NAME" --assignee-object-id "$principal_id" --assignee-principal-type "ServicePrincipal" --scope "\/subscriptions\/$subscription_id"
    log "Role: $IMPACT_REPORTER_ROLE_NAME assigned to the app with Id: $app_id"
  else
    log "Role: $IMPACT_REPORTER_ROLE_NAME already assigned to the app with Id: $app_id"
  fi

  if ! has_role_assignment "$principal_id" "$MONITORING_READER_ROLE_NAME"; then
    az role assignment create --role "$MONITORING_READER_ROLE_NAME" --assignee-object-id "$principal_id" --assignee-principal-type "ServicePrincipal" --scope "\/subscriptions\/$subscription_id"
    log "Role: $MONITORING_READER_ROLE_NAME assigned to the app with Id: $app_id"
  else
    log "Role: $MONITORING_READER_ROLE_NAME already assigned to the app with Id: $app_id"
  fi

  log "Successfully setup permissions for impact reporting" 
}

has_role_assignment()
{
  user_principal_name=$1
  role_name=$2

  role_definition_name=$(az role assignment list --assignee "$user_principal_name" --query "[?roleDefinitionName=='$role_name' ]" --include-groups --include-inherited | jq -r .[0].roleDefinitionName)
  if [ "$role_definition_name" == "$role_name" ]; then
    return 0
  else
    return 1
  fi
}

check_role_assignment_for_setting_up_permissions()
{
  subscription_id=$1
  user_principal_name=$2

  if ! has_role_assignment "$user_principal_name" "Role Based Access Administrator" && ! has_role_assignment "$user_principal_name" "User Access Administrator" ; then
    log "You are neither a 'Role Based Access Administrator' nor a 'User Access Administrator' on the subscription: $subscription_id which is required to assign monitoring reader and impact reporter permissions to the app. Please reach out to someone in your organization who can assign one of these roles to you. Once you have them, run this script again."
    exit 1
  fi
}

check_role_assignment_for_feature_registration()
{
  subscription_id=$1
  user_principal_name=$2

  if ! has_role_assignment "$user_principal_name" "Contributor"; then
    log "You are not a 'Contributor' on the subscription: $SubscriptionId which is required to register impact reporting feature flag. Please reach out to someone in your organization who can assign one of these roles to you. Once you have them, run this script again."
    exit 1
  fi
}


verify_permissions()
{
  subscription_id=$1
  user_principal_name=$2
  log "Verifying permissions for $user_principal_name for the subscription: $subscription_id"

  if has_role_assignment "$user_principal_name" "Owner" ; then
    log "Permissions are already set for the subscription: $subscription_id for $user_principal_name"
  else
    check_role_assignment_for_setting_up_permissions "$subscription_id" "$user_principal_name" 
    check_role_assignment_for_feature_registration "$subscription_id" "$user_principal_name"
  fi
}

generate_secret()
{
  if [[ "$consent" == "Y" || "$consent" == "y" ]]; then
    log "User consented to secret creation. Creating secret..."
    clientsecretduration=2
    APP_SECRET_VALUE=$(az ad app credential reset --id $app_id --append --display-name $APP_SECRET_NAME --years $clientsecretduration --query password --output tsv)
    log "Secret created successfully."
  else
    log "Secret is not created as user did not provide consent."
  fi
}

run_impact_reporting_onboarding_steps()
{
  log "==== Starting Impact Reporting Onboarding for Dynatrace ===="
  
  # Check if the file is given and exists
  if [ -n "$file_path" ] && [ -f "$file_path" ]; then
      # Read the file into an array
      mapfile -t subscription_ids < "$file_path"
  else
      # Create an array with a single element
      subscription_ids=("$subscription_id")
  fi
  
  signed_in_user=$(az ad signed-in-user show)
  user_principal_name=$(echo "$signed_in_user" | jq -r .userPrincipalName)

  if [ $use_existing_app = false ]; then
    log "Creating a new app registration with display name: $APP_REGISTRATION_NAME"
    app_id=$(az ad app create --display-name $APP_REGISTRATION_NAME --query appId --output tsv)
    log "App registration created successfully with Id: $app_id"
  fi
  
  for current_subscription_id in "${subscription_ids[@]}"; do
      az_login_with_prompt "${current_subscription_id//$'\r'/}"  # Remove carriage return character if present
      verify_permissions "$current_subscription_id" "$user_principal_name"
      register_feature "Microsoft.Impact" "AllowImpactReporting"
      setup_required_permissions "$current_subscription_id"
      log "==== Configuration is successfully setup on your subscription: $current_subscription_id!! ===="
  done

  log "==== Starting secret creation for the app with Id: $app_id ===="
  generate_secret
  log "==== Configuration is successfully setup on your subscription(s) ===="

  tenant_id=$(az account show --query tenantId --output tsv)
  
  echo -e "${BOLD}${WHITE_BG}Follow the instructions at the following link to complete onboarding: https://github.com/Azure/impact-reporting-samples/blob/main/docs/index.md#impact-reporting-dynatrace-connector"
  echo ""
  echo "Please note the following values as they are necessary to complete the onboarding process."
  echo "Tenant Id: $tenant_id"
  echo "App Id: $app_id"
  if [ -z "$APP_SECRET_VALUE" ]; then
    echo ""
    echo "Secret is not created because user did not provide consent."
    echo "Please follow the instructions at the following link to create a client secret manually: https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app?tabs=client-secret#add-credentials"
    echo "Please find your app registration on the azure portal here: https://ms.portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$app_id"
    echo "Once you have created the secret, you can go back to the Dynatrace environment to proceed for onboarding."
  else
    echo "Secret: $APP_SECRET_VALUE"
  fi
  echo -e "${RESET}"
}

main()                                                                                                                                                               
{
  use_existing_app=false

  # Get the command line environment value.                                                                                                                          
  while [[ $# -gt 0 ]]; do                                                                                                                                           
      opt="$1"                                                                                                                                                       
      shift;                                                                                                                                                         
      current_arg="$1"                                                                                                                                               
      if [[ "$current_arg" =~ ^-{1,2}.* ]]; then                                                                                                                     
        log "ERROR: You have left an argument blank. Double check your command."                                                                                     
        exit 1                                                                                                                                                       
      fi                                                                                                                                                             
      case "$opt" in                                                                                                                                                 
        "--app-id"                                   ) app_id="$1"; use_existing_app=true; shift;;
        "--subscription-id"                        	 ) subscription_id="$1"; shift;;
        "--file-path"                           	   ) file_path="$1"; shift;;                                                                                
        "--help"                                     ) print_help; exit 0;;                                                                                     
        *                                            ) log "ERROR: Invalid option: \"$opt\"" && print_help >&2 exit 1;;                                         
      esac                                                                                                                                                           
  done                                                                                                                           
  
  validate_input
  read -p "We would create and display a secret against the app registration. Do you consent to secret creation and displaying it against the app registration? (Y/N): " consent
  if [[ "$consent" == "Y" || "$consent" == "y" ]]; then
    log "Consented to creating app secret."
  else
    log "Not consented to creating app secret."
  fi
  run_impact_reporting_onboarding_steps
}                                                                                                                                                                    
                                                                                                                                                                     
main "$@"                                                                                                                                                            