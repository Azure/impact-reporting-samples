# Failures
 
## Work Execution failure / Insights Page failure

### Error: No app settings found
1. Head over to the app settings for "Impact Reporting Connector Dynatrace" app.
2. Ensure that app settings are present with appropriate values for Tenant Id, Credential Vault Secret Id and Onboarding Status

### Error: AADSTS700016 - Application not found
1. Find the application Id from error message. Validate that this app is listed in Microsoft Entra Id. ([Click to find list of app registrations in your tenant](https://ms.portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps))
2. Head over to the app settings for "Impact Reporting Connector Dynatrace" app
    - Tenant Id specified in app settings should match the tenant for which the problem is triggered. 

### Error: AADSTS7000215 - Invalid client secret
1. Head over to the app settings for "Impact Reporting Connector Dynatrace" app and note the Credential Vault Secret Id.
    - Go to Credential vault app in dynatrace
    - Ensure that credential with id noted in first step is present in the credential vault app.
2. Find "DynatraceImpactReportingConnectorApp" under app registrations in Micrsoft Entra Id.
    - Create a secret for this app registration
    - Note the secret and client id of the app registration
    - Find the credential in credential vault as mentioned in step 1.
    - Overwrite the credential passing client id under user name and secret under password.
    - Save the credential.

### Error: Blocked Request (Host not in allowlist)
1. Dyntrace blocks all external calls by default.
2. How allow authentication and impact reporting, the follow URLs have to be allow-listed.
    - login.microsoftonline.com
    - management.azure.com
3. Search "Limit outbound connections" on dynatrace. Add the above URLs to the list of allowed hosts.

### Insights Page: Request Timeout
1. This means the external call to fetch insights took too long to return results.
2. Use the Refresh button on top of the table to attempt fetching insights again.

### Insights Page: Failed to fetch impacts insights
1. Use the Refresh button on top of the table to attempt fetching insights again.
2. If the issue persists, check the console logs to get a detailed error message. (Press F2 and then Click on Console)
3. Use the error message to see if it matches with any of the above mentioned errors.
