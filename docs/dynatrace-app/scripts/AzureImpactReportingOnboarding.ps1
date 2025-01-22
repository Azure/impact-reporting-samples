param (
    [string]$AppId,
    [string]$SubscriptionId,
    [string]$FilePath,
    [switch]$help
)

$ErrorActionPreference = 'Stop'; # Similar to 'set -e' in bash, stops execution on first error
Set-PSDebug -Trace 0 # Similar to 'set -x' in bash, prints each command that gets executed

$IMPACT_REPORTER_ROLE_NAME = "Impact Reporter"
$MONITORING_READER_ROLE_NAME = "Monitoring Reader"
$APP_REGISTRATION_NAME = "DynatraceImpactReportingConnectorApp"
$APP_SECRET_NAME = "DynatraceOnboardingSecret"
$global:APP_SECRET_VALUE = ""

function Print-Help {
    Write-Host ""
    Write-Host "# # ############ USAGE ############ #"
    Write-Host "#"
    Write-Host "# AzureImpactReportingOnboarding.ps1"
    Write-Host "#            -SubscriptionId <The subscription id of the subscription for onboarding to impact reporting.>"
    Write-Host "#            -FilePath <The file path where newline separated list of subscriptions for onboarding to impact reporting.>"
    Write-Host "#            -AppId <(Optional, not recommended) The app id of the existing app registration to be used for role assignment and secret generation. If not provided, a new app registration will be created.>"
    Write-Host "#            -help <Print this help page>"
    Write-Host "# "
    Write-Host "# This script is used to set-up pre-requisites and onboard one or more subscriptions for Azure Impact Reporting. It does the following:"
    Write-Host "# 1. Creates a new Entra App, otherwise uses an existing one."
    Write-Host "# 2. Registers the preview feature AllowImpactReporting in subscriptions considered for onboarding."
    Write-Host "# 3. Registers the resource provider Microsoft.Impact in subscriptions considered for onboarding."
    Write-Host "# 4. Optionally, if consented, generates a secret to complete onboarding."
    Write-Host "#"
    Write-Host "# Note: This script takes ~20 minutes to complete execution."
    Write-Host "# # ############ ##### ############ #"
    Write-Host ""
}

function Log {
    param (
        [string]$msg
    )
    $date = Get-Date
    Write-Host "$date - $msg"
}

function Az-Login-With-Prompt {
    param (
        [string]$SubscriptionId
    )

    if (-not (az account show)) {
        Log "Login to Azure"
        az login
    }

    Log "Setting Azure subscription as $SubscriptionId"
    az account set --subscription $SubscriptionId
}

function Validate-Input {
    if (-not $SubscriptionId -and -not $FilePath) {
        Log "Please provide required input: SubscriptionId or FilePath with list of subscription IDs while invoking the script"
        exit 1
    }

    if ($SubscriptionId -and $FilePath) {
        Log "Please provide either SubscriptionId or FilePath with list of subscription IDs while invoking the script. Do not provide both."
        exit 1
    }

    if ($SubscriptionId) {
        Log "Using Subscription ID = $SubscriptionId"
    }

    if ($FilePath) {
        if (-not (Test-Path $FilePath)) {
            Log "Failed to find file: $FilePath. Please provide a valid file path that you have access to"
            exit 1
        }
        Log "Subscription IDs will be read from the file: $FilePath"
    }

    if ($use_existing_app) {
        if (-not $AppId) {
            Log "Optional input app-id cannot be empty. Consider running the script without --app-id, if you do not want to use an existing app registration."
            exit 1
        }

        $AppId = az ad app show --id $AppId --query appId --output tsv
        Log "Using App ID: $AppId"
    }

    Log "==== All required inputs are present ===="
}

function Register-Namespace {
    param (
        [string]$namespace
    )

    Log "Registering namespace - $namespace"
    az provider register -n $namespace
    Verify-Namespace-Registration $namespace
    Log "Successfully registered namespace - $namespace"
}

function Verify-Namespace-Registration {
    param (
        [string]$namespace
    )

    Log "Verifying registration for namespace $namespace, namespace registration can take up to several minutes"
    $registration_status = az provider show -n $namespace | ConvertFrom-Json | Select-Object -ExpandProperty registrationState
    $attempt_count = 1
    $sleep_duration = 60
    while ($registration_status -ne "Registered") {
        Log "Attempt # ${attempt_count}: Waiting for $sleep_duration seconds before retrying."
        Start-Sleep -Seconds $sleep_duration
        $attempt_count++
        Log "Attempt #${attempt_count}: Verifying registration status for namespace - $Namespace"
        $registration_status = az provider show -n $namespace | ConvertFrom-Json | Select-Object -ExpandProperty registrationState
        Log "Registration status: $registration_status"
    }
    Log "Registration of namespace - $namespace is successful"
}

function Register-Feature {
    param (
        [string]$namespace,
        [string]$feature_name
    )

    $registration_status = az feature register --name $feature_name --namespace $namespace | ConvertFrom-Json | Select-Object -ExpandProperty properties | Select-Object -ExpandProperty state

    if ($registration_status -ne "Registered") {
        Log "Started registration of feature - $feature_name in namespace - $namespace"
        Verify-Feature-Registration $namespace $feature_name
        Log "Successfully registered feature - $feature_name in namespace - $namespace"
    }
    else {
        Log "Feature $feature_name in namespace $namespace is already registered"
    }

    Log "Getting the changes for the feature $feature_name in namespace $namespace propogated to the subscription"
    Register-Namespace $namespace
    Log "Changes for the feature $feature_name in namespace $namespace are propogated to the subscription"
}

function Verify-Feature-Registration {
    param (
        [string]$namespace,
        [string]$feature_name
    )

    Log "Verifying registration for feature: $feature_name in namespace $namespace, feature registration can take up to several minutes"
    $registration_status = ""
    $attempt_count = 1
    $sleep_duration = 60
    while ($registration_status -ne "Registered") {
        Log "Attempt #${attempt_count}: Waiting for $sleep_duration seconds before retrying."
        Start-Sleep -Seconds $sleep_duration
        $attempt_count++
        Log "Attempt #${attempt_count}: Verifying registration status for $feature_name in namespace $namespace"
        $registration_status = az feature list -o json --query "[?contains(name, '$namespace/$feature_name')].{Name:name,State:properties.state}" | ConvertFrom-Json | Where-Object { $_.Name -eq "$namespace/$feature_name" } | Select-Object -ExpandProperty State
        Log "Registration status: $registration_status"
    }
}

function Setup-Required-Permissions {
    param (
        [string]$SubscriptionId
    )

    Log "Setting up permissions for impact reporting and monitoring reader"
    Log "Assigning the Role: $IMPACT_REPORTER_ROLE_NAME to the app with Id: $AppId"

    $principal_id = az ad sp list --filter "appId eq '$AppId'" --query "[].id" --output tsv
    if (-not $principal_id) {
        Log "Service principal does not exist. Creating service principal for the app with Id: $AppId"
        $principal_id = az ad sp create --id $AppId --query id --output tsv
        Log "Service principal with Id: $principal_id created successfully for the app with Id: $AppId"
    }
    else {
        Log "Service principal with Id: $principal_id already exists for the app with Id: $AppId"
    }

    if (-not (Has-Role-Assignment $principal_id $IMPACT_REPORTER_ROLE_NAME)) {
        az role assignment create --role $IMPACT_REPORTER_ROLE_NAME --assignee-object-id $principal_id --assignee-principal-type "ServicePrincipal" --scope "/subscriptions/$SubscriptionId"
        Log "Role: $IMPACT_REPORTER_ROLE_NAME assigned to the app with Id: $AppId"
    }
    else {
        Log "Role: $IMPACT_REPORTER_ROLE_NAME already assigned to the app with Id: $AppId"
    }

    if (-not (Has-Role-Assignment $principal_id $MONITORING_READER_ROLE_NAME)) {
        az role assignment create --role $MONITORING_READER_ROLE_NAME --assignee-object-id $principal_id --assignee-principal-type "ServicePrincipal" --scope "/subscriptions/$SubscriptionId"
        Log "Role: $MONITORING_READER_ROLE_NAME assigned to the app with Id: $AppId"
    }
    else {
        Log "Role: $MONITORING_READER_ROLE_NAME already assigned to the app with Id: $AppId"
    }

    Log "Successfully setup permissions for impact reporting"
}

function Has-Role-Assignment {
    param (
        [string]$user_principal_name,
        [string]$role_name
    )

    $role_definition_name = az role assignment list --assignee $user_principal_name --query "[?roleDefinitionName=='$role_name']" --include-groups --include-inherited | ConvertFrom-Json | Select-Object -First 1 | Select-Object -ExpandProperty roleDefinitionName
    return $role_definition_name -eq $role_name
}

function Check-Role-Assignment-For-Setting-Up-Permissions {
    param (
        [string]$SubscriptionId,
        [string]$user_principal_name
    )

    if (-not (Has-Role-Assignment $user_principal_name "Role Based Access Administrator") -and -not (Has-Role-Assignment $user_principal_name "User Access Administrator")) {
        Log "You are neither a 'Role Based Access Administrator' nor a 'User Access Administrator' on the subscription: $SubscriptionId which is required to assign monitoring reader and impact reporter permissions to the app. Please reach out to someone in your organization who can assign one of these roles to you. Once you have them, run this script again."
        exit 1
    }
}

function Check-Role-Assignment-For-Feature-Registration {
    param (
        [string]$SubscriptionId,
        [string]$user_principal_name
    )
  
    if (-not (Has-Role-Assignment $user_principal_name "Contributor")) {
        Log "You are not a 'Contributor' on the subscription: $SubscriptionId which is required to register impact reporting feature flag. Please reach out to someone in your organization who can assign one of these roles to you. Once you have them, run this script again."
        exit 1
    }
}

function Verify-Permissions {
    param (
        [string]$SubscriptionId,
        [string]$user_principal_name
    )

    Log "Verifying permissions for the subscription: $SubscriptionId"

    if (Has-Role-Assignment $user_principal_name "Owner") {
        Log "Permissions are already set for the subscription: $SubscriptionId"
    }
    else {
        Check-Role-Assignment-For-Setting-Up-Permissions $SubscriptionId $user_principal_name
        Check-Role-Assignment-For-Feature-Registration $SubscriptionId $user_principal_name
    }
}

function Generate-Secret {
    if ($consent -eq "Y" -or $consent -eq "y") {
        log "User consented to secret creation. Creating secret..."
        $clientsecretduration = 2
        $global:APP_SECRET_VALUE = az ad app credential reset --id $AppId --append --display-name $APP_SECRET_NAME --years $clientsecretduration --query password --output tsv
        log "Secret created successfully."
    }
    else {
        log "Secret is not created as user did not provide consent."
    }
}

function Run-Impact-Reporting-Onboarding-Steps {
    Log "==== Starting Impact Reporting Onboarding for Dynatrace ===="

    if ($FilePath -and (Test-Path $FilePath)) {
        $SubscriptionIds = Get-Content -Path $FilePath
    }
    else {
        $SubscriptionIds = @($SubscriptionId)
    }

    $signed_in_user = az ad signed-in-user show | ConvertFrom-Json
    $user_principal_name = $signed_in_user.userPrincipalName

    if (-not $use_existing_app) {
        Log "Creating a new app registration with display name: $APP_REGISTRATION_NAME"
        $AppId = az ad app create --display-name $APP_REGISTRATION_NAME --query appId --output tsv
        Log "App registration created successfully with Id: $AppId"
    }

    foreach ($current_SubscriptionId in $SubscriptionIds) {
        Az-Login-With-Prompt $current_SubscriptionId.Trim()
        Verify-Permissions $current_SubscriptionId $user_principal_name
        Register-Feature "Microsoft.Impact" "AllowImpactReporting"
        Setup-Required-Permissions $current_SubscriptionId
        Log "==== Configuration is successfully setup on your subscription: $current_SubscriptionId!! ===="
    }

    Log "==== Starting secret creation for the app with Id: $AppId ===="
    Generate-Secret
    Log "==== Configuration is successfully setup on your subscription(s) ===="

    $tenant_id = (az account show --query tenantId -o tsv)
    Write-Host "Follow the instructions at the following link to complete onboarding: https://github.com/Azure/impact-reporting-samples/blob/main/docs/index.md#impact-reporting-dynatrace-connector" -ForegroundColor Black -BackgroundColor White
    Write-Host "" -ForegroundColor Black -BackgroundColor White
    Write-Host "Please note the following values as they are necessary to complete the onboarding process." -ForegroundColor Black -BackgroundColor White
    Write-Host "Tenant Id: $tenant_id" -ForegroundColor Black -BackgroundColor White
    Write-Host "App Id: $AppId" -ForegroundColor Black -BackgroundColor White
    if ($global:APP_SECRET_VALUE -eq "") {
        Write-Host "" -ForegroundColor Black -BackgroundColor White
        Write-Host "Secret is not created because user did not provide consent." -ForegroundColor Black -BackgroundColor White
        Write-Host "Please follow the instructions at the following link to create a client secret manually: https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app?tabs=client-secret#add-credentials" -ForegroundColor Black -BackgroundColor White
        Write-Host "Please find your app registration on the azure portal here: https://ms.portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$AppId" -ForegroundColor Black -BackgroundColor White
        Write-Host "Once you have created the secret, you can go back to the Dynatrace environment to proceed for onboarding." -ForegroundColor Black -BackgroundColor White
    }
    else {
        Write-Host "Secret: $global:APP_SECRET_VALUE" -ForegroundColor Black -BackgroundColor White
    }
    Write-Host ""
}

if ($help) {
    Print-Help
    exit 0
}

$use_existing_app = $false
if ($AppId) {
    $use_existing_app = $true
}

Validate-Input
$consent = Read-Host "We would create a secret and display it against the app registration. Do you consent to secret creation and displaying it against the app? (Y/N):"
if ($consent -eq "Y" -or $consent -eq "y") {
    Log "Consented to creating app secret."
}
else {
    Log "Not consented to creating app secret."
}
Run-Impact-Reporting-Onboarding-Steps