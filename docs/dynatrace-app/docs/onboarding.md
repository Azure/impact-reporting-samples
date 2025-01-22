# Welcome to the Onboarding Guide for Azure Impact Reporting app for Dynatrace 🚀

Congratulations on choosing **Azure Impact Reporting app for Dynatrace**! This guide is here to help you get started quickly and easily. Whether you're a first-time user or setting up the app for your team, this onboarding guide provides step-by-step instructions to ensure a smooth and successful setup.

## What You’ll Learn in This Guide

In this guide, you’ll find:

- **Prerequisites:** What you need to have before starting.
- **Installation:** How to download and set up the app.
- **Configuration:** Setting up your environment for optimal performance.
- **Verification:** Testing your setup to ensure everything works.
- **Next Steps:** Links to advanced features, documentation, and tips to get the most out of the app.

## Who Is This Guide For?

This guide is designed for:

- **New Users:** Quickly set up the app and begin exploring its features.
- **Team Admins:** Configure the app for use in your organization.
- **Developers:** Get the app ready for integration with your projects.

---

## Onboarding Azure Impact Reporting (Preview) app

### Prerequisites

Before you begin, ensure you have:

- [ ] A valid account with necessary access permissions to an Azure tenant and Dynatrace environment.
- [ ] Access to the latest app binary from the [releases folder](../releases/).
- [ ] You must have the app-engine:apps:install permission in your Dynatrace environment.
- [ ] Have [run the impact reporting script in Azure](#run-the-impact-reporting-onboarding-script-in-azure)

#### Run the Impact Reporting Onboarding script in Azure

##### Permissions Needed on Azure to run the deployment script

Ensure you have Contributor permission in subscription(s) that you choose to onboard for Impact Reporting. You also need 'User Access Administrator or Role Based Access Administrator' permission to assign the 'Impact Reporter' and 'Monitoring Reader' role to the Entra App that will be used to report impacts from these subscriptions.

###### The deployment script does the following:-

    a) Registers the resource provider Microsoft.Impact and associated feature flag for Impact Reporting within the customers' Azure subscription(s).
    b) Optionally, creates a third-party Azure Entra App with a secure secret to ensure pipeline security. 
    c) Grant the app the 'ImpactReporter' and 'Monitoring Reader' permissions on subscription(s).

###### Running the onboarding script

1) Download the scripts from the [scripts folder](../scripts/).
2) Onboarding single subscription

   Shell script

        ./azure-impact-reporting-onboarding.sh --subscription_id <subscription id> 

    Powershell

        ./AzureImpactReportingOnboarding.ps1 -SubscriptionId <subscription id> 

3) Onboarding multiple subscriptions

    Shell script

        ./azure-impact-reporting-onboarding.sh --file-path <file path to the file that has new line separated list of subscriptions to be onboarded>

    Powershell

        ./AzureImpactReportingOnboarding.ps1 -FilePath <file path to the file that has new line separated list of subscriptions to be onboarded>
4) Note the output of the script as it will be required in upcoming steps.

### Azure Impact Reporting (Preview) app onboarding is a 3 step process

1) [Update Dynatrace Settings](#1-update-dynatrace-settings)
2) [Upload and install the app in your Dynatrace environment](#2-to-upload-and-install-your-app-in-dynatrace)
3) [Onboard the Azure Impact Reporting (Preview) app](#3-onboard-the-azure-impact-reporting-preview-app)

#### 1. Update Dynatrace Settings

To make calls to AAD and ARM:

    a) Go to Dynatrace Home --> Click Search on the left Panel  
    b) Search for 'Limit outbound connections' 
    c) Add the following to the list: 
        login.microsoftonline.com
        management.azure.com
        graph.microsoft.com

#### 2. To Upload and install your app in Dynatrace

1) Please download the app binaries from the [releases folder](../releases/).
2) The customer should log in to their preferred Dynatrace environment
   1) Open the Hub app
   2) Navigate to the Manage tab
   3) Click the upload button
   4) Select the app artifact from the file picker
   5) Confirm the installation. To complete this step, the user must have the app-engine:apps:install permission.

The app will require the following permissions from Dynatrace

    app-settings:objects:read - To read app settings that holds the tenant and credential information required to report impacts and fetch insights.
    app-settings:objects:write: To write to app settings values for tenant and credential information required to report impacts and fetch insights.
    environment-api:credentials:read: To read credential value that is used to get the access token for accessing the Microsoft APIs for reporting impacts and fetching insights.
    environment-api:credentials:write: To write to credential vault the credentials that are used to get an access token for accessing the Microsoft APIs for reporting impacts and fetching insights.
    automation:workflows:read: Read the created workflow that is used to report impacts.
    storage:entities:read: Read azure resource related information to report impact against.

As this app creates a workflow that triggers on a problem and does query execution using DQL to fetch additional details associated with a problem, there is a small cost incurred. Please review costing details here: [Rate Card](https://www.dynatrace.com/pricing/rate-card/)

#### 3. Onboard the Azure Impact Reporting (Preview) app

1) Open the Azure Impact Reporting (Preview) App
2) Click on the 'Get Started' button once you have completed the pre-requisite of [Run the Impact Reporting Onboarding script in Azure](#run-the-impact-reporting-onboarding-script-in-azure)
3) Input the Azure Tenant ID, Azure Entra App ID, Azure Entra App Secret that was obtained as the output of [running the Impact Reporting onboarding script in Azure](#run-the-impact-reporting-onboarding-script-in-azure)

![Azure Entra App Configuration Page](./images/Azure%20Entra%20App%20Configuration%20Page.png)
4) Click 'Next' </br>
5) In the section for 'Onboard to Impact Reporting', click on "Create Workflow".

![Onboard to Impact Reporting Page](./images/Onboard%20to%20Impact%20Reporting%20Page.png)
6) A new tab will open for you that will create the workflow **'Azure Impact Reporter'**, once the workflow is created successfully. Your onboarding is completed. You can close the new tab.

>**Note:** Once onboarded, this app creates some entries in app settings that are essential for a smooth execution. Customers are recommended to refrain from making changes to these app settings. Editing these app settings can hamper with app execution leading to unexpected results.

>**Note:** It has been observed in some cases that, workflow execution fails with an error `InsufficientPermission: NOT_AUTHORIZED_FOR_TABLE`. If this error is seen, make the following changes to your settings in workflows app:</br>
    a) In the Workflows app, at the top right corner, find Settings. </br>
    b) Click on Settings and then Authorization Settings.</br>
    c) Under Primary permissions, select all permissions. </br>
    c) Under Secondary permissions, select permissions for 'environment-api' </br>
    d) Save changes and re-run the failed execution(s) </br>

### Support/Questions/Comments

Please refer to the [troubleshooting guide](troubleshooting.md) or create a Github issue [here](https://github.com/Azure/impact-reporting-samples/issues/new?template=Blank+issue) or reach to our [support team](mailto:impactrp-preview@microsoft.com) for additional assistance.
