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
  Write-Host "# EnableImpactReporting.ps1"
  Write-Host "#            -SubscriptionId: The subscription id of the subscription that is getting onboarded to ImpactRP"
  Write-Host "#            -FilePath: The file path where newline separated list of subscriptions is present"
  Write-Host "#            -Help: Print this help page"
  Write-Host "# "
  Write-Host "# This cmdlet is for enabling impact reporting on your subscription(s)."
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
      "Description" = "Allows for reading alerts and writing impacts."
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
      [string]$Message
  )

  $date = Get-Date
  Write-Host "$date - $Message" 2>&1
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
  $RoleName = "Azure-Alerts-Reader-Role" # DND
  $ConnectorAppName = "AzureImpactReportingConnector"

  $RoleId = (Get-AzRoleDefinition -Name $RoleName).id
  if (-not $RoleId) {
      Log "Creating custom role for alert reading."
      $CustomRoleJsonFilePath = "/tmp/impact-reporting-role.json"
      CreateCustomRoleJson $SubscriptionId $RoleName | Out-File $CustomRoleJsonFilePath
      $RoleId = (New-AzRoleDefinition -InputFile $CustomRoleJsonFilePath).id
      Log "Custom role: $RoleName for alert reading created successfully with role id: $RoleId."
      Remove-Item -Path $CustomRoleJsonFilePath
  }
  else {
      Log "Custom role: $RoleName for alert reading already exists with role id: $RoleId."
  }

  Log "Assigning the custom role: $RoleName to the reporting app: $ConnectorAppName"
  $ConnectorPrincipalId = (Get-AzADServicePrincipal -DisplayName $ConnectorAppName).id

  $AssignedCustomRole = Get-AzRoleAssignment -ObjectId $ConnectorPrincipalId -RoleDefinitionId $RoleId -Scope "/subscriptions/$SubscriptionId"

  if (-not $AssignedCustomRole) {
      New-AzRoleAssignment -ObjectId $ConnectorPrincipalId -RoleDefinitionId $RoleId -Scope "/subscriptions/$SubscriptionId"
      Log "Custom role: $RoleName assigned to the reporting app: $ConnectorAppName"
  }
  else {
      Log "Custom role: $RoleName already assigned to the reporting app: $ConnectorAppName"
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
      $ResponseBody = (Invoke-AzRestMethod -Method Put -Path $Path -Payload $request_body).Content | ConvertFrom-Json
      $ProvisioningState = $ResponseBody.properties.provisioningState 
      if ($ProvisioningState -ne "Succeeded")
      {
        $SleepDuration = $SleepDuration * 2
        Log "Attempt #${AttemptCount}: Connector creation is in progress. Waiting for $SleepDuration seconds before retrying."
        Start-Sleep -Seconds $SleepDuration
        $AttemptCount = $AttemptCount + 1
      }
      else
      {
        Log "Attempt #${AttemptCount}: Creation of connector: $ConnectorName is successful."
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

function Enable-ImpactReporting {
  param (
      [array]$SubscriptionIds
  )
  # Loop through the array
  foreach ($item in $SubscriptionIds) {
      LoginAzWithPrompt $item
      Register-Feature "Microsoft.Impact" "AzureImpactReportingConnector"
      Register-Feature "Microsoft.Impact" "AllowImpactReporting"
      Add-PermissionsForAlertReading $item
      CreateConnector $item
      Log "==== Impact reporting is now enabled on your subscription: $item!! ===="
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

Log "==== Enabling impact reporting ===="
Enable-ImpactReporting -SubscriptionIds $SubscriptionIds
Log "==== Impact reporting is successfully enabled on your subscription(s) ===="