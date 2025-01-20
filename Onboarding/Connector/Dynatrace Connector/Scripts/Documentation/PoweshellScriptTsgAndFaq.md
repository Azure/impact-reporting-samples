# For the powershell script

## FAQ

### How do I run the script?

Use the below commands

For single subscription

```powershell
AzureImpactReportingOnboarding.ps1 -SubscriptionId <subscription_id>
```

For new line separated subscription list in a file

```powershell
AzureImpactReportingOnboarding.ps1 -FilePath <file_path>
```

### Can I run this script for multiple subscriptions at once?

Yes, use the `-FilePath` option with a file containing newline-separated subscription IDs.

### What permissions are needed to run this script?

To ensure the onboarding script works seamlessly, the following permissions are required:

1. **Contributor Permissions**: At the subscription level, this role is needed for executing steps related to:
   1. Resource provider registration
   2. Feature flag registration

2. **Role Based Access Administrator/User Access Administrator Permissions**: At the subscription level, this role is needed for executing steps related to:
   1. Assigning the 'Impact Reporter' role to the Azure service principal **'DynatraceImpactReportingConnectorApp'**
   2. Assigning the 'Monitoring Reader' role to the Azure service principal **'DynatraceImpactReportingConnectorApp'**

In summary, a combination of these permissions will be sufficient to run the script effectively.

### How do I enable debug mode?

Change `Set-PSDebug -Trace 0` to `Set-PSDebug -Trace 1` at the beginning of the script to enable debug mode

### What should I do if I encounter a permission error?

Verify your Azure role and permissions. You may need the help of your Azure administrator to grant you the necessary permissions or roles as defined the permissions section.

### How can I verify if the onboarding was completed successfully?

1. Navigate to: https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/<subscription id>/users
2. Click on the 'Role Assignments' tab
3. Search for 'DynatraceImpactReportingConnectorApp'
4. The app should have: 'Impact Reporter' and 'Monitoring Reader' role assigned to it
5. From the left blade, navigate to Settings -> Resource providers
6. Search for 'Microsoft.Impact'
7. It should be registered

### TSG

### Error "SubscriptionId or FilePath with list of subscription IDs required"

Make sure to provide either the `-SubscriptionId` parameter or the `-FilePath` parameter when invoking the script. Do not provide both.

### Error "Failed to find file: [FilePath]"

Verify the file path provided with `-FilePath` exists and is accessible. Ensure the correct path is used and the file is not locked or in use by another process.

### Error "Optional input AppId can not be empty"

It is recommended not to use this option when executing the script for the first set of subscriptions. For subsequent subscription onboarding, ensure the app ID of the 'DynatraceImpactReportingConnectorApp' is passed as an input to the script.

### Script fails to execute with permission errors

Ensure you have **Contributor** permission to log in to Azure and register resource providers in the Azure subscriptions.
You also need to have **'User Access Administrator or Role Based Access Administrator'** permission to assign the 'Impact Reporter' and 'Monitoring Reader' role to the 'DynatraceImpactReportingConnectorApp' application.

### Script execution stops unexpectedly without completing

Check if the Azure PowerShell module is installed and up to date. Use `Update-Module -Name Az` to update the Azure PowerShell module. Ensure `$ErrorActionPreference` is set to `'Continue'` temporarily to bypass non-critical errors.

### Namespace or feature registration takes too long or fails

These operations can take several minutes (~20 minutes). Ensure your Azure account has the **Contributor** access on the subscription(s). Re-run the script once the required access has been provided. If the issue persists on re-running create a Github issue [here](https://github.com/Azure/impact-reporting-samples/issues/new?template=Blank+issue)

### Role assignment fails

1. Verify your account has **'User Access Administrator or Role Based Access Administrator'** permission to assign roles.

### Log line: 'Secret is not created as user did not provide consent.'

This means that the script did not generate a secret for the 'DynatraceImpactReportingConnectorApp'. It is required that this app has a secret associated with it, as the secret value is necessary for performing the onboarding steps in Dynatrace. This app ID and secret combination is used to acquire the access token for reporting impacts and fetching insights.

To create the secret, simply re-run the script and provide 'Y' as the input when asked for consent with the following prompt:

```bash
   We would create and display a secret against the app registration. Do you consent to secret creation and displaying it against the app registration? (Y/N): 
```

If you do not wish to generate the secret via the script please follow the instructions at [this link](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app?tabs=client-secret#add-credentials) to create a client secret manually for the application 'DynatraceImpactReportingConnectorApp'

This TSG and FAQs aim to cover common scenarios encountered while running the `CreateImpactReportingConnector.ps1` script. For issues not covered here, create a Github issue [here](https://github.com/Azure/impact-reporting-samples/issues/new?template=Blank+issue)