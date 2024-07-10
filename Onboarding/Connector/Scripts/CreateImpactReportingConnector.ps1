param (
      [switch]$help,
      [string]$SubscriptionId,
      [string]$FilePath
)

$ErrorActionPreference = 'Stop'; # Similar to 'set -e' in bash, stops execution on first error
Set-PSDebug -Trace 0 # Similar to 'set -x' in bash, prints each command that gets executed

function PrintHelp {
  Write-Host "`n"
  Write-Host "# # ############ USAGE ############ #"
  Write-Host "#"
  Write-Host "# CreateImpactReportingConnector.ps1"
  Write-Host "#            -SubscriptionId: The subscription id of the subscription where the connector will be created"
  Write-Host "#            -FilePath: The file path where newline separated list of subscriptions, where the connector(s) will be created, is present"
  Write-Host "#            -Help: Print this help page"
  Write-Host "# "
  Write-Host "# This cmdlet is used to set-up pre-requisites and create Impact Reporting Connector(s) in one or more subscriptions."
  Write-Host "#"
  Write-Host "# # ############ ##### ############ #"
  Write-Host "`n"
}

function CreateCustomRoleJson {
  param (
      [string]$SubscriptionId,
      [string]$RoleName
  )

  $json = @{
      "Name" = $RoleName
      "IsCustom" = $true
      "Description" = "Allows for reading alerts."
      "Actions" = @(
          "Microsoft.AlertsManagement/alerts/read"
      )
      "AssignableScopes" = @(
          "/subscriptions/$SubscriptionId"
      )
  } | ConvertTo-Json

  return $json
}


function Log {
  param (
      [string]$Message,
      [string]$ForegroundColor
  )

  $date = Get-Date
  if (-not $ForegroundColor) {
    Write-Host "$date - $Message" 2>&1
  }
  else {
    Write-Host "$date - $Message" -ForegroundColor $ForegroundColor 2>&1
  }
}

function LoginAzWithPrompt {
  param (
      [string]$SubscriptionId
  )

  if (-not (Get-AzContext)) {
      Log "Login to Azure"
      Connect-AzAccount
  }

  Log "Setting Azure subscription as $SubscriptionId"
  Set-AzContext -Subscription $SubscriptionId
}

function Register-Namespace {
  param (
      [string]$Namespace
  )

  Log "Registering namespace - $Namespace"

  Register-AzResourceProvider -ProviderNamespace "$Namespace"

  Test-NamespaceRegistration $Namespace
  Log "Successfully registered namespace - $Namespace"
}

function Test-NamespaceRegistration {
  param (
      [string]$Namespace
  )

  Log "Verifying registration for namespace $Namespace, namespace registration can take upto several minutes"
  $RegistrationStatus = ""
  $AttemptCount = 1
  $SleepDuration = 10
  while ($RegistrationStatus -ne "Registered") {
      Log "Attempt #${AttemptCount}: Verifying registration status for namespace - $Namespace"
      $RegistrationStatus =  (Get-AzResourceProvider -ProviderNamespace "$Namespace").RegistrationState
      $SleepDuration = $SleepDuration * 2
      Log "Attempt #${AttemptCount}: Waiting for $SleepDuration seconds before retrying."
      Start-Sleep -Seconds $SleepDuration
      $AttemptCount = $AttemptCount + 1
  }
  Log "Registration of namespace - $Namespace is successful"
}

function Register-Feature {
  param (
      [string]$Namespace,
      [string]$FeatureName
  )

  $RegistrationStatus = (Register-AzProviderFeature -FeatureName $FeatureName -ProviderNamespace $Namespace).RegistrationState

  if ($RegistrationStatus -ne "Registered") {
      Log "Started registration of feature - $FeatureName in namespace - $Namespace"
      Test-FeatureRegistration $Namespace $FeatureName
      Log "Successfully registered feature - $FeatureName in namespace - $Namespace"
  }
  else {
      Log "Feature $FeatureName in namespace $Namespace is already registered"
  }

  Log "Getting the changes for the feature $FeatureName in namespace $Namespace propagated to the subscription"
  Register-Namespace $Namespace
  Log "Changes for the feature $FeatureName in namespace $Namespace are propagated to the subscription"
}


function Test-FeatureRegistration {
  param (
      [string]$Namespace,
      [string]$FeatureName
  )

  Log "Verifying registration for feature: $FeatureName in namespace $Namespace, feature registration can take upto several minutes"
  $RegistrationStatus = ""
  $AttemptCount = 1
  $SleepDuration = 10
  while ($RegistrationStatus -ne "Registered") {
      Log "Attempt #${AttemptCount}: Verifying registration status for $FeatureName in namespace $Namespace"
      $RegistrationStatus = (Get-AzProviderFeature -ProviderNamespace "$Namespace" -FeatureName "$FeatureName").RegistrationState
      $SleepDuration = $SleepDuration * 2
      Log "Attempt #${AttemptCount}: Waiting for $SleepDuration seconds before retrying."
      Start-Sleep -Seconds $SleepDuration
      $AttemptCount = $AttemptCount + 1
  }
}

function Add-PermissionsForAlertReading {
  param (
      [string]$SubscriptionId
  )

  Log "Setting up permissions for alert reading"
  $ConnectorAppName = "AzureImpactReportingConnector"

  $RoleId = (Get-AzRoleDefinition -Name $ALERTS_READER_ROLE_NAME).id
  if (-not $RoleId) {
      Log "Creating custom role for alert reading."
      $CustomRoleJsonFilePath = "/tmp/azure-alerts-reader-role-definition.json"
      CreateCustomRoleJson $SubscriptionId $ALERTS_READER_ROLE_NAME | Out-File $CustomRoleJsonFilePath
      $RoleId = (New-AzRoleDefinition -InputFile $CustomRoleJsonFilePath).id
      Log "Custom role: $ALERTS_READER_ROLE_NAME for alert reading created successfully with role id: $RoleId."
      Remove-Item -Path $CustomRoleJsonFilePath
  }
  else {
      Log "Custom role: $ALERTS_READER_ROLE_NAME for alert reading already exists with role id: $RoleId."
  }

  Log "Assigning the custom role: $ALERTS_READER_ROLE_NAME to the reporting app: $ConnectorAppName"
  $ConnectorPrincipalId = (Get-AzADServicePrincipal -DisplayName $ConnectorAppName).id

  $AssignedCustomRole = Get-AzRoleAssignment -ObjectId $ConnectorPrincipalId -RoleDefinitionId $RoleId -Scope "/subscriptions/$SubscriptionId"

  if (-not $AssignedCustomRole) {
      New-AzRoleAssignment -ObjectId $ConnectorPrincipalId -RoleDefinitionId $RoleId -Scope "/subscriptions/$SubscriptionId"
      Log "Custom role: $ALERTS_READER_ROLE_NAME assigned to the reporting app: $ConnectorAppName"
  }
  else {
      Log "Custom role: $ALERTS_READER_ROLE_NAME already assigned to the reporting app: $ConnectorAppName"
  }

  Log "Successfully setup permissions for alert reading"
}

function CreateConnector {
  param (
      [string]$SubscriptionId
  )

  $ConnectorName = "AzureMonitorConnector"
  Log "Creating connector: $ConnectorName for impact reporting"

  $request_body = @{
      "properties" = @{
          "connectorType" = "AzureMonitor"
      }
  } | ConvertTo-Json

  $QueryParam="?api-version=2024-05-01-preview"
  $Path = "subscriptions/$SubscriptionId/providers/Microsoft.Impact/connectors/$ConnectorName$QueryParam"

  $AttemptCount = 1
  $SleepDuration = 10
  $ProvisioningState=""
  do
  {
      $Response = (Invoke-AzRestMethod -Method Put -Path $Path -Payload $request_body)
      $ResponseContent = $Response.Content
      $StatusCode = $Response.StatusCode
      if ( $StatusCode -eq 409 ) {
          Log "A connector is already deployed in this subscription. A new connector will not be deployed." -ForegroundColor yellow
          break;
      }
      $ResponseBody = $ResponseContent | ConvertFrom-Json
      $ProvisioningState = $ResponseBody.properties.provisioningState 
      if ($StatusCode -eq 404 -and $ResponseBody.error.code -eq "InvalidResourceType" )
      {
        $SleepDuration = $SleepDuration * 2
        Log "Attempt #${AttemptCount}: Connector creation is in progress. Waiting for $SleepDuration seconds before retrying."
        Start-Sleep -Seconds $SleepDuration
        $AttemptCount = $AttemptCount + 1
      }
      elseif($ProvisioningState -eq "Succeeded")
      {
        Log "Attempt #${AttemptCount}: Creation of connector: $ConnectorName is successful."
      }
      else
      {
        Write-Host "Connector creation failed with status code: $StatusCode and response body: $ResponseContent" -ForegroundColor red
        exit 1;
      }
      
  } while ($ProvisioningState -ne "Succeeded")
}

function Test-Input {
  param (
      [string]$SubscriptionId,
      [string]$FilePath
  )

  if ((-not $SubscriptionId) -and (-not $FilePath)) {
      Log "Please provided required input: SubscriptionId or FilePath with list of subscription IDs while invoking the script"
      PrintHelp
      exit 1
  }
  if ($SubscriptionId -and $FilePath) {
      Log "Please provided either SubscriptionId or FilePath with list of subscription IDs while invoking the script. Do not provide both."
      PrintHelp
      exit 1
  }

  if ($SubscriptionId) {
      Log "Using Subscription ID = $SubscriptionId"
  }

  if ($FilePath) {
      if (-not (Test-Path -Path $FilePath)) {
          Log "Failed to find file: $FilePath. Please provide a valid file path that you have access to"
          exit 1
      }
      Log "Subscription IDs will be read from the file: $FilePath"
  }

  Log "==== All required inputs are present ===="
}

function HasRoleAssignment {
  param (
      [string]$RoleName,
      [string]$SubscriptionId
  )

  $RoleDefinitionName = (Get-AzRoleAssignment -ObjectId $AzureAdId -RoleDefinitionName $RoleName -Scope /subscriptions/$SubscriptionId).RoleDefinitionName
  return $RoleName -eq $RoleDefinitionName
}

function CheckRoleAssignmentForSettingUpPermissions {
  param (
      [string]$SubscriptionId
  )

  $RoleId = (Get-AzRoleDefinition -Name $ALERTS_READER_ROLE_NAME).id
  if (-not $roleId) {
      Write-Host "Custom role: $ALERTS_READER_ROLE_NAME for alerts reading does not exist. Checking for built-in role: User Access Administrator role assignment as that is required for custom role creation"
      if (-not (HasRoleAssignment -SubscriptionId $SubscriptionId -RoleName "User Access Administrator")) {
          Write-Host "You are not a 'User Access Administrator' on the subscription: $SubscriptionId. Please get the role assigned to proceed"
          exit 1
      }
  }

  if (-not (HasRoleAssignment -SubscriptionId $SubscriptionId -RoleName "Role Based Access Administrator") -and -not (HasRoleAssignment -SubscriptionId $SubscriptionId -RoleName "User Access Administrator")) {
      Write-Host "You are neither a 'Role Based Access Administrator' nor a 'User Access Administrator' on the subscription: $SubscriptionId which is required to assign alert reading permission to the connectors app. Please get the role assigned to proceed"
      exit 1
  }
}

function CheckRoleAssignmentForDeployment {
  param (
      [string]$SubscriptionId
  )

  if (-not (HasRoleAssignment -SubscriptionId $SubscriptionId -RoleName "Contributor")) {
      Write-Host "You are not a 'Contributor' on the subscription: $SubscriptionId which is required to create the connector on your subscription. Please get the role assigned to proceed."
      exit 1
  }
}

function VerifyPermissions {
  param (
      [string]$SubscriptionId
  )

  Write-Host "Verifying permissions for the subscription: $SubscriptionId"

  if (HasRoleAssignment -SubscriptionId $SubscriptionId -RoleName "Owner") {
      Write-Host "Permissions are already set for the subscription: $SubscriptionId"
  } else {
      CheckRoleAssignmentForSettingUpPermissions -SubscriptionId $SubscriptionId
      CheckRoleAssignmentForDeployment -SubscriptionId $SubscriptionId 
  }
}

function CreateImpactReportingConnectors {
  param (
      [array]$SubscriptionIds
  )

  foreach ($CurrentSubscriptionId in $SubscriptionIds) {
      LoginAzWithPrompt $CurrentSubscriptionId
      VerifyPermissions $CurrentSubscriptionId
      Register-Feature "Microsoft.Impact" "AzureImpactReportingConnector"
      Register-Feature "Microsoft.Impact" "AllowImpactReporting"
      Add-PermissionsForAlertReading $CurrentSubscriptionId
      CreateConnector $CurrentSubscriptionId
      Log "==== Impact reporting connector is successfully created on your subscription: $CurrentSubscriptionId!! ===="
  }
}

if ($help) {
  PrintHelp
  exit
}  

Test-Input -SubscriptionId $SubscriptionId -FilePath $FilePath

# Check if the file is given and exists
if ($FilePath -and (Test-Path -Path $FilePath)) {
  # Read the file into an array
  $SubscriptionIds = Get-Content -Path $FilePath
}
else {
  # Create an array with a single element
  $SubscriptionIds = @($SubscriptionId)
}

$ALERTS_READER_ROLE_NAME = "Azure-Alerts-Reader-Role"
$AzureAdId = (Get-AzADUser -SignedIn).Id

Log "==== Creating impact reporting connector(s) ===="
CreateImpactReportingConnectors -SubscriptionIds $SubscriptionIds
Log "==== Impact reporting connector is successfully created on your subscription(s), please head on the onboarding guide: https://aka.ms/impactRP/AzMonConnectorDocs for next step(s) ===="