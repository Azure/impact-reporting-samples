# Report impacts using webhook based logic app

Click on the button below to deploy the logic app in your azure subscription.

[![Deploy](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchand45%2FTestRepo2%2Fmain%2Ftemplate.json)

## Prerequistes for arm template deployment
Logic app needs the following input parameters:

1. Region: Azure region where the logic app is deployed. Region is automatically populated with the selected resource group's location. Select the region from drop down if you are creating a new resource group.

2. Logic App Name: Defaulted to ImpactReportingConnectorLite. You can also give it any name you want.

3. Managed Identity Name: Name of the User Assigned Managed Identity resource.

4. Managed Identity SubscriptionId: Subscription where the managed identity is created.

5. Managed Identity Resource Group: Resource Group where the managed identity is created.

## What does the logic app do?
- The logic app serves as a REST client for reporting impacts.
- It acts as a wrapper on top of the REST api for reporting impacts, providing the ability to seamlessly report impacts by simplifying the authentication overhead.
- A User Assigned Managed Identity (UAMI) is used to securely authenticate against Impact RP and report impacts.
- Logic App provides the ability to report impacts against all the subscriptions that the UAMI has access to.
- UAMI needs Impact Reporter role to report impacts against a subscription.

## How do I trigger the logic app?

### 1. Trigger Logic App from portal
- Head over to the logic app resource
- Click on Run --> Run with payload
![alt text](../../../../docs/assets/LogicApp.png)
- A pop up opens on the right.
- Construct the impact payload and click on run to report impact.
![alt text](../../../../docs/assets/TriggerLogicApp.png)
- Check the run history from logic app's overview page.

### 2. Trigger Logic App from a REST client
- You can also trigger logic app from a REST client of your choice!
- Copy the workflow URL from logic app overview page.
- Make a PUT call to this URL, with impact payload in the body.
- Check the run history from logic app's overview page. 


You can also find the full API reference for workload impacts here: [Workload Impacts API Reference](https://learn.microsoft.com/en-us/rest/api/impact/workload-impacts/create?view=rest-impact-2024-05-01-preview&tabs=HTTP)