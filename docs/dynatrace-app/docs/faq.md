# Frequently Asked Questions (FAQ)

Welcome to the **FAQ section** for the Azure Impact Reporting app for Dynatrace! This document is designed to answer the most common questions about our app, covering topics like setup, usage, troubleshooting, and more. Whether you're just starting out or looking for advanced tips, you’ll find clear and concise answers here.

If your question isn't listed, don't worry! You can always reach out to our [support team](mailto:impactrp-preview@microsoft.com) for additional assistance.

---

## How to Use This FAQ

- Browse the categories below to find your question.
- Click on a question to jump directly to its answer.
- Use your browser’s search function (`Ctrl + F` or `Cmd + F`) to quickly locate specific terms.

[FAQ for the bash script](#faq-for-the-bash-script) </br>
[FAQ for the powershell script](#faq-for-the-powershell-script)

---

Let’s dive into the most commonly asked questions!

# FAQ for the bash script

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


# FAQ for the powershell script

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
   1. Assigning the 'Impact Reporter' role to the Azure service principal **'DynatraceImpactReportingConnectorApp'** or to the custom app id provided while running the script.
   2. Assigning the 'Monitoring Reader' role to the Azure service principal **'DynatraceImpactReportingConnectorApp'** or to the custom app id provided while running the script.

In summary, a combination of these permissions will be sufficient to run the script effectively.

### How do I enable debug mode?

Change `Set-PSDebug -Trace 0` to `Set-PSDebug -Trace 1` at the beginning of the script to enable debug mode

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
