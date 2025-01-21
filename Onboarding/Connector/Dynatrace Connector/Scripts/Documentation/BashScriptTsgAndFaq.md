# For the bash script

## FAQ

### How do I run the script?

Use the below commands

For single subscription

```bash
chmod +x azure-impact-reporting-onboarding.sh
./azure-impact-reporting-onboarding.sh --subscription-id <subscription_id>
```

For new line separated subscription list in a file

```bash
chmod +x azure-impact-reporting-onboarding.sh
./azure-impact-reporting-onboarding.sh --file-path <file_path>
```

### Can I run this script for multiple subscriptions at once?

Yes, use the `--file-path` option with a file containing newline-separated subscription IDs.

### What permissions are needed to run this script?

To ensure the onboarding script works seamlessly, the following permissions are required:

1. **Contributor Permissions**: At the subscription level, this role is needed for executing steps related to:
   1. Resource provider registration
   2. Feature flag registration

2. **Role Based Access Administrator/User Access Administrator Permissions**: At the subscription level, this role is needed for executing steps related to:
   1. Assigning the 'Impact Reporter' role to the Azure service principal **'DynatraceImpactReportingConnectorApp'** or to the custom app id provided while running the script.
   2. Assigning the 'Monitoring Reader' role to the Azure service principal **'DynatraceImpactReportingConnectorApp'** or to the custom app id provided while running the script.

In summary, a combination of these permissions will be sufficient to run the script effectively.

### How do I enable debug mode?

Uncomment the `set -x` at the beginning of the script to enable debug mode.

### What should I do if I encounter a permission error?

Verify your Azure role and permissions. You may need the help of your Azure administrator to grant you the necessary permissions or roles as defined the permissions section.

### How can I verify if the onboarding was completed successfully?

1. Navigate to: https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/[subscription_id]/users
2. Click on the 'Role Assignments' tab
3. Search for 'DynatraceImpactReportingConnectorApp' or for the custom app id provided while running the script.
4. The app should have: 'Impact Reporter' and 'Monitoring Reader' role assigned to it
5. From the left blade, navigate to Settings -> Resource providers
6. Search for 'Microsoft.Impact'
7. It should be registered

### Can I use multiple app-ids for various subscription?

No, in this version of the onboarding, using multiple app IDs is not supported. While the script will run successfully with different app IDs for subsequent runs, the Dynatrace app 'Azure Impact Reporting (Preview)' does not support multiple apps to multiple subscription mappings. This means that impact reporting and insight fetching cannot occur for subscriptions that are not linked to the same app ID registered with the Dynatrace app during the onboarding process.

### Troubleshooting Guide (TSG)

### The bash script fails immediately after starting

Ensure that the script has execution permissions. Use the below command to make it executable.

```bash
chmod +x azure-impact-reporting-onboarding.sh
```

### Azure login fails (az login command not working)

Ensure [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) is installed and updated to the latest version. Try manually logging in using `az login` to check for any additional prompts or errors.

### Error "Subscription ID or file path with list of subscription IDs required"

Make sure you are providing either `--subscription-id` or `--file-path` argument when executing the script. Do not provide both.

### Error "Failed to find file: [file_path]"

Verify the file path provided with `--file-path` exists and is accessible. Ensure the correct path is used.

### Error "Optional input app-id can not be empty"

It is recommended not to use this option when executing the script for the first set of subscriptions. For subsequent subscription onboarding, ensure the app ID of the 'DynatraceImpactReportingConnectorApp' is passed as an input to the script.

In case you have onboarded the first set of subscriptions with you own app-id using this option, kindly ensure that the subsequent subscription onboarding also happens with the same app id.

### Script fails to execute with permission errors

Ensure you have **Contributor** permission to log in to Azure and register resource providers in the Azure subscriptions.
You also need to have **'User Access Administrator or Role Based Access Administrator'** permission to assign the 'Impact Reporter' and 'Monitoring Reader' role to the 'DynatraceImpactReportingConnectorApp' application or to the custom app id provided while running the script.

### Namespace or feature registration takes too long or fails

These operations can take several minutes (~20 minutes). Ensure your Azure account has the **Contributor** access on the subscription(s). Re-run the script once the required access has been provided. If the issue persists on re-running create a Github issue [here](https://github.com/Azure/impact-reporting-samples/issues/new?template=Blank+issue)

### Role assignment fails

1. Verify your account has **'User Access Administrator or Role Based Access Administrator'** permission to assign roles.

### Log line: 'Secret is not created as user did not provide consent.'

This means that the script did not generate a secret for the 'DynatraceImpactReportingConnectorApp' or to the custom app id provided while running the script. It is required that this app has a secret associated with it, as the secret value is necessary for performing the onboarding steps in Dynatrace. This app ID and secret combination is used to acquire the access token for reporting impacts and fetching insights.

To create the secret, simply re-run the script and provide 'Y' as the input when asked for consent with the following prompt:

```bash
   We would create and display a secret against the app registration. Do you consent to secret creation and displaying it against the app registration? (Y/N): 
```

If you do not wish to generate the secret via the script please follow the instructions at [this link](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app?tabs=client-secret#add-credentials) to create a client secret manually for the application 'DynatraceImpactReportingConnectorApp'

This covers the common scenarios encountered while running the `azure-impact-reporting-onboarding.sh` script. For issues not covered here, create a Github issue [here](https://github.com/Azure/impact-reporting-samples/issues/new?template=Blank+issue)
