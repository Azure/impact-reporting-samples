# For the bash script

## FAQ

### How do I run the script?

Use the below commands

For single subscription

```bash
chmod +x create-impact-reporting-connector.sh
./create-impact-reporting-connector.sh --subscription-id <subscription_id>
```

For new line separated subscription list in a file

```bash
chmod +x create-impact-reporting-connector.sh
./create-impact-reporting-connector.sh --file-path <file_path>
```

### Can I run this script for multiple subscriptions at once?

Yes, use the `--file-path` option with a file containing newline-separated subscription IDs.

### What permissions are needed to run this script?

To ensure the onboarding script works seamlessly, the following permissions are required:

1. **Contributor Permissions**: At the subscription level, this role is needed for executing steps related to:
   1. Resource provider registration
   2. Feature flag registration
   3. Impact reporting connector resource creation

2. **Role Creation Permissions**: To create a custom role that can read alerts generated from the subscription, one of the following roles is necessary:
   1. User Access Administrator
   2. Role Based Access Control Administrator

In summary, a combination of these permissions will be sufficient to run the script effectively.

### How do I enable debug mode?

Uncomment the `set -x` at the beginning of the script to enable debug mode.

### What should I do if I encounter a permission error?

Verify your Azure role and permissions. You may need the help of your Azure administrator to grant you the necessary permissions or roles as defined the permissions section.

### How can I verify if the connector is successfully created?

Run the below command in AzCli

```bash
az rest --method get --url "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Impact/connectors?api-version=2024-05-01-preview"
```

You should see a resource with the name: **AzureMonitorConnector**

Or

1. Navigate to [Azure Resource Graph Explorer](https://portal.azure.com/#view/HubsExtension/ArgQueryBlade)
2. Run the below query

   ```kql
    impactreportresources
        | where name == "AzureMonitorConnector" 
            and type == "microsoft.impact/connectors"
   ```

3. The results should look like below, with a row for the connector resource

![Viewing the Connector in ARG](Images/Viewing%20the%20Connector%20in%20ARG.png)

### Troubleshooting Guide (TSG)

### The bash script fails immediately after starting

Ensure that the script has execution permissions. Use the below command to make it executable.

```bash
chmod +x create-impact-reporting-connector.sh
```

### Azure login fails (az login command not working)

Ensure [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) is installed and updated to the latest version. Try manually logging in using `az login` to check for any additional prompts or errors.

### Error "Subscription ID or file path with list of subscription IDs required"

Make sure you are providing either `--subscription-id` or `--file-path` argument when executing the script. Do not provide both.

### Error "Failed to find file: [file_path]"

Verify the file path provided with `--file-path` exists and is accessible. Ensure the correct path is used.

### Script fails to execute with permission errors

Ensure you have **Contributor** permission to log in to Azure, register resource providers, and create connectors in the Azure subscriptions.
You also need to have either of **'User Access Administrator'** or **'Role Based Access Control Administrator'** permissions to create and assign custom roles.

### Namespace or feature registration takes too long or fails

These operations can take several minutes. Ensure your Azure account has the **Contributor** access on the subscription(s). Re-run the script once the required access has been provided. If the issue persists on re-running reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com)

### Custom role creation or assignment fails

1. Ensure the Azure Service Principal **'AzureImpactReportingConnector'** exists by entering it into the search box as shown below, if not wait for a few minutes for it to get created. If it does not get created even after an hour, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com).
   ![AzureImpactReportingConnector](Images/Checking%20the%20Service%20Principal.png)
2. Verify your account has either of **'User Access Administrator'** or **'Role Based Access Control Administrator'** permissions to create roles and assign them.

### Connector creation takes too long

It can take about 15-20 minutes for the namespace registration to allow the connector resource creation to take place. Even after 30 minutes if the script has not completed execution, cancel the script execution and re-run it. If this run also get stuck, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com)

### Connector creation fails

1. Ensure that the RPs: **Microsoft.Impact** is registered. You can do this in 2 ways -
   1. From the Azure Portal, navigate to your Subscription -> Resource Providers
      ![Viewing the resource provider in portal](Images/Viewing%20the%20Resource%20Provider%20In%20Portal.png)

   2. Run the below command

      ```bash
      az provider show -n "Microsoft.Impact" -o json --query "registrationState"
      ```

      ![Viewing the resource provider in AzCli](Images/Viewing%20the%20Resource%20Provider%20In%20AzCli.png)

2. Ensure that the feature flags: **AllowImpactReporting** and **AzureImpactReportingConnector** are registered against the feature: **Microsoft.Impact**
   Run the below command

   ```bash
      az feature list -o json --query "[?contains(name, 'Microsoft.Impact/AllowImpactReporting')].{Name:name,State:properties.state}"
      az feature list -o json --query "[?contains(name, 'Microsoft.Impact/AzureImpactReportingConnector')].{Name:name,State:properties.state}"
      ```

      ![Viewing the feature flags](Images/Viewing%20the%20Feature%20Flags%20In%20AzCli.png)

3. Ensure that you have **Contributor** access to the subscription(s)

This covers the common scenarios encountered while running the `create-impact-reporting-connector.sh` script. For issues not covered here, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com).
