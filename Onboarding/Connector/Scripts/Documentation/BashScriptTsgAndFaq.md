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

You need to have **Contributor** permission to log in to Azure, register resource providers, and create connectors in the Azure subscriptions. You also need to have either of **'Owner'**, **'User Access Administrator'** and **'Privileged Role Administrator'** permissions to create and assign custom roles.

### How do I enable debug mode?

Uncomment the `set -x` at the beginning of the script to enable debug mode.

### What should I do if I encounter a permission error?

Verify your Azure role and permissions. You may need the help of your Azure administrator to grant you the necessary permissions or roles as defined the permissions section.

### How can I verify if the connector is successfully created?

Run the below command

```bash
az rest --method get --url "https://management.azure.com/subscriptions/<subscription-id>/providers/Microsoft.Impact/connectors?api-version=2024-05-01-preview"
```

You should see a resource with the name: **AzureMonitorConnector**

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

This covers the common scenarios encountered while running the `create-impact-reporting-connector.sh` script. For issues not covered here, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com).
