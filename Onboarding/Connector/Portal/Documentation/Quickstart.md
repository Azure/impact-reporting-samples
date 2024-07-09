---
title: Quickstart - Creating a Impact Reporting Connector
description: Use the Azure portal to create connectors for Azure Monitor alerts
author: Stuti Srivastava
---

# Quickstart: Creating a Impact Reporting Connector

Impact Reporting Connector can be created through the Azure portal. This quickstart shows you how to use the Azure portal to create the connector.

If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.

## Sign in to Azure

Sign in to the [Azure portal](https://portal.azure.com).

## Create a connector

1. Enter **Impact Reporting Connectors** in the search
2. Click on the **Create** button on the left side in the page. The **Create Impact Reporting Connector** page opens

    ![Create Impact Reporting Connector page](Images/Create%20Impact%20Reporting%20Connector%20page.png)

3. From the **Subscription** drop down select the subscription where the Connector will be created
4. Under **Instance details**, enter *AzureMonitorConnector* for the **Connector name** and choose *AzureMonitor* for the **Connector type**.
5. Select the **Review + create** button at the bottom of the page
6. Once the validations have passed, and the **Review + Create** shows no error, click on **Create** at the bottom of the page

   ![Review + Create tab](Images/Review%20and%20Create%20tab.png) 

7. The deployment can take several minutes to complete, as there are feature flags that need registration which can take some time to propagate. Meanwhile, head to the next section to enable alert reading from your subscription

## Allowing the connector to read alerts

In order for the connector to report impacts, our first party app: **AzureImpactReportingConnector** needs to have alerts reader permission. The below steps allow the alert reading permission to our app, by creating a custom role.

### Prerequisites

To create custom roles, you need:

- Permissions to create custom roles, such as [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) or [User Access Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator)

### Assigning Azure-Alerts-Reader-Role to 'AzureImpactReportingConnector'

1. Navigate to your subscription, and select **Access Control (IAM)** from the navigation blade
2. Click **Add** and then click **Add role assignment**. This will open the **Add role assignment** page. 
3. Under the **Role** tab, in the search bar, type *Azure-Alerts-Reader-Role*. If this role does not exist, head to [Creating the Azure-Alerts-Reader-Role](#creating-the-azure-alerts-reader-role) to create this role. Once the role is created, return back to this step.

    ![Add custom role](Images/Role%20Assignment/Role%20Selection.png)

4. Select the *Azure-Alerts-Reader-Role* and click on **Next** button at the bottom of the page
5. Under the **Members** tab, select **User, group, or service principal** for **Assign access to**.
6. Click on **Select members**, which will open the **Select Members** blade on the right side.
7. Enter **AzureImpactReportingConnector** in the search bar, and click on the AzureImpactReportingConnector application. Then click **Select** button.

    ![Member Assignment](Images/Role%20Assignment/Member%20Selection.png)

8. Select the **Review + assign** button at the bottom of the page
9. In the **Review + assign** tab, click on **Review + assign** button at the bottom of the page

### Creating the Azure-Alerts-Reader-Role

1. Navigate to your subscription, and select **Access Control (IAM)** from the navigation blade
2. Click **Add** and then click **Add custom role**. This will open the **Create a custom role** page

    ![Add custom role](Images/Custom%20Role/Add%20Custom%20Role.png)

3. Under the **Basics** tab, enter the name **Azure-Alerts-Reader-Role** for the **Custom role name**. Leave others as defaults and click on **Next** on the bottom of the page

    ![Basics tab](Images/Custom%20Role/Basics%20Tab.png)

4. Under the **Permissions** tab, click on **Add permissions**. On the right side, **Add permissions** blade will open

    ![Basics tab](Images/Custom%20Role/Permissions%20Tab.png)

5. Enter *Microsoft.AlertsManagement/alerts/read* in the search bar

    ![Basics tab](Images/Custom%20Role/Add%20Permissions.png)

6. Select the tile **Microsoft.AlertsManagement**, which will take you to the **Microsoft.AlertsManagement permissions** blade. Select the permission: **Read: Read alerts**. Click on **Add**

    ![Permission Selection](Images/Custom%20Role/Permission%20Selection.png)

7. Select the **Review + create** button at the bottom of the page
8. In the **Review + create** tab, click on **Create** button at the bottom of the page

## Troubleshooting

### Connector deployment fails to due to permission errors

Ensure you have **Contributor** permission to log in to Azure, register resource providers, and create connectors in the Azure subscriptions.

### Custom role assignment fails to due to permission errors

You also need to have [Owner](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) or [User Access Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#user-access-administrator) role to create and assign custom roles.

### Connector creation takes too long

It can take about 15-20 minutes for the namespace registration to allow the connector resource creation to take place. Even after 30 minutes if the script has not completed execution, cancel the script execution and re-run it. If this run also get stuck, reach out to the [Impact RP connectors team](mailto:impactrp-preview@microsoft.com)