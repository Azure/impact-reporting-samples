# For the powershell script

## FAQ

### How do I run the script?

Use the below commands

For single subscription

```powershell
.\CreateImpactReportingConnector.ps1 -SubscriptionId <subscription_id>
```

For new line separated subscription list in a file

```powershell
.\CreateImpactReportingConnector.ps1 -FilePath <file_path>
```

### Can I run this script for multiple subscriptions at once?

Yes, use the `-FilePath` option with a file containing newline-separated subscription IDs.

### What permissions do I need to run this script?

You need to have **Contributor** permission to log in to Azure, register resource providers, and create connectors in the Azure subscriptions. You also need to have either of **'Owner'**, **'User Access Administrator'** and **'Privileged Role Administrator'** permissions to create and assign custom roles.

### How do I enable debug mode?

Change `Set-PSDebug -Trace 0` to `Set-PSDebug -Trace 1` at the beginning of the script to enable debug mode

### What should I do if I encounter a permission error?

Verify your Azure role and permissions. You may need the help of your Azure administrator to grant you the necessary permissions or roles as defined the permissions section.

### How can I verify if the connector is successfully created?

Run the below command

```powershell
(Invoke-AzRestMethod -Method Get -Path subscriptions/<Subscription Id>/providers/Microsoft.Impact/connectors?api-version=2024-05-01-preview).Content
```

You should see a resource with the name: **AzureMonitorConnector**

### TSG

### Script fails to execute with permission errors

Ensure you have **Contributor** permission to log in to Azure, register resource providers, and create connectors in the Azure subscriptions. You also need to have either of **'Owner'**, **'User Access Administrator'** and **'Privileged Role Administrator'** permissions to create and assign custom roles.

### Script execution stops unexpectedly without completing

Check if the Azure PowerShell module is installed and up to date. Use `Update-Module -Name Az` to update the Azure PowerShell module. Ensure `$ErrorActionPreference` is set to `'Continue'` temporarily to bypass non-critical errors.

### Error "SubscriptionId or FilePath with list of subscription IDs required"

Make sure to provide either the `-SubscriptionId` parameter or the `-FilePath` parameter when invoking the script. Do not provide both.

### Error "Failed to find file: [FilePath]"

Verify the file path provided with `-FilePath` exists and is accessible. Ensure the correct path is used and the file is not locked or in use by another process.

### Namespace or feature registration takes too long or fails

These operations can take several minutes. Ensure your Azure account has the **Contributor** access on the subscription(s). Re-run the script once the required access has been provided. If the issue persists on re-running reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com)

### Custom role creation or assignment fails

1. Ensure the Azure Service Principal **'AzureImpactReportingConnector'** exists, if not wait for a few minutes for it to get created. If it does not get created even after an hour, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com).
2. Verify your account has either of **'Owner'**, **'User Access Administrator'** and **'Privileged Role Administrator'** permissions to create roles and assign them.

### Connector creation takes too long

It can take about 15-20 minutes for the namespace registration to allow the connector resource creation to take place. Even after 30 minutes if the script has not completed execution, cancel the script execution and re-run it. If this run also get stuck, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com)

### Connector creation fails

1. Ensure that the RPs: **Microsoft.Impact** is registered.
2. Ensure that the feature flags: **AllowImpactReporting** and **AzureImpactReportingConnector** are registered against the feature: **Microsoft.Impact**
3. Ensure that you have **Contributor** access to the subscription(s)

This TSG and FAQs aim to cover common scenarios encountered while running the `CreateImpactReportingConnector.ps1` script. For issues not covered here, reviewing the script's output and Azure