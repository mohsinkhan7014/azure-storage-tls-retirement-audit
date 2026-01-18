# Azure Storage TLS Retirement Audit - Getting Started Guide

## Overview
This guide walks you through capturing and analyzing TLS versions used by clients connecting to your Azure Storage accounts before Microsoft retires TLS 1.0 and 1.1 in February 2026.

**Estimated Time**: 30-45 minutes

---

## Step 1: Register Azure Service Principal & Grant Permissions

Before deploying infrastructure, you need a Service Principal with Contributor role.

### Option A: Using Azure Portal
1. Go to **Azure Portal** → **Azure Active Directory** → **App Registrations**
2. Click **+ New Registration**
   - **Name**: `tls-audit-sp` (or preferred name)
   - **Supported Account Types**: Accounts in this organizational directory only
3. Click **Register**

4. **Copy these values** (you'll need them in Step 2):
   - **Application (client) ID** → use as `client_id`
   - **Directory (tenant) ID** → use as `tenant_id`

5. Create a client secret:
   - In the app registration, go to **Certificates & secrets**
   - Click **+ New client secret**
   - **Expiration**: 24 months
   - Click **Add**
   - **Copy the secret value immediately** → use as `client_secret` (⚠️ you can't see it again!)

6. Grant Contributor role:
   - Go to **Subscriptions** → Your subscription
   - Click **Access Control (IAM)**
   - Click **+ Add** → **Add role assignment**
   - **Role**: Contributor
   - **Assign to**: Service Principal
   - **Select**: `tls-audit-sp` (search for your app name)
   - Click **Review + assign**

### Option B: Using Azure CLI
```powershell
# Create Service Principal
az ad sp create-for-rbac --name "tls-audit-sp" --role Contributor

# Output will show:
# "appId": "<client_id>"
# "password": "<client_secret>"
# "tenant": "<tenant_id>"
```

---

## Step 2: Configure Terraform Variables

1. **Copy the example file**:
   ```powershell
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your actual values:
   ```hcl
   subscription_id     = "your-subscription-id"          # From Azure Portal → Subscriptions
   tenant_id           = "00000000-0000-0000-..."        # From Step 1
   client_id           = "00000000-0000-0000-..."        # From Step 1
   client_secret       = "your-secret-value"             # From Step 1 (⚠️ Keep this safe!)
   
   resource_group_name = "rg-TLS-Capture"                # Name for your resource group
   location            = "centralus"                     # Azure region (e.g., eastus, westus, etc.)
   ```

3. **⚠️ Never commit `terraform.tfvars`** - it contains secrets! (.gitignore already protects this)

---

## Step 3: Deploy Infrastructure with Terraform

### Prerequisites
- **Terraform** >= 1.0 installed ([Download](https://www.terraform.io/downloads))
- **Azure CLI** authenticated: `az login`

### Initialize and Deploy
```powershell
# Navigate to project directory
cd azure-storage-tls-retirement-audit

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply -auto-approve
```

**What gets created**:
- ✅ Azure Resource Group
- ✅ Log Analytics Workspace (for centralized logging)
- ✅ 2 Test Storage Accounts with different TLS versions:
  - `makranaappst1` with TLS 1.0
  - `makranaappst2` with TLS 1.1

**Note**: For testing only, use these sample accounts. For production, add your own non-compliant storage accounts in Step 4.

---

## Step 4: Identify Non-Compliant Storage Accounts

Create or update the **StorageAccounts.xlsx** file in the project root directory with your storage accounts.

**File Location**: `./StorageAccounts.xlsx` (same directory as DiagEnable.ps1 and RemoveDiag.ps1)

**Excel Format** - Two columns required:

| StorageAccountName | ResourceGroupName |
|---|---|
| mystorageacct1 | rg-production |
| mystorageacct2 | rg-production |
| makranaappst1 | rg-TLS-Capture |
| makranaappst2 | rg-TLS-Capture |

**Notes**:
- **For testing only**: Use the 2 sample accounts created by Terraform (`makranaappst1`, `makranaappst2`)
- **For production**: Add your own non-compliant storage accounts (those with TLS 1.0 or 1.1)
- The TLS version will be detected from the storage account configuration in Azure
- Save the file in the project root directory before running Step 6

---

## Step 5: Install PowerShell Module & Connect to Azure

### Install ImportExcel Module
```powershell
# Install the module (requires Admin PowerShell)
Install-Module -Name ImportExcel -Force -Scope CurrentUser

# Verify installation
Get-Module ImportExcel -ListAvailable
```

### Authenticate to Azure
```powershell
# Login to Azure
Connect-AzAccount

# Verify correct subscription
Get-AzContext

# If wrong subscription, switch it
Select-AzSubscription -SubscriptionId "your-subscription-id"
```

---

## Step 6: Enable Diagnostics Across Storage Accounts

This step captures all TLS client connection information to Log Analytics Workspace.

```powershell
# Navigate to project directory
cd azure-storage-tls-retirement-audit

# Run the diagnostic enablement script
.\DiagEnable.ps1
```

**What the script does**:
1. Reads all storage accounts from `StorageAccounts.xlsx`
2. Enables diagnostic settings for:
   - ✅ Blob Storage (StorageRead, StorageWrite, StorageDelete)
   - ✅ Queue Storage
   - ✅ File Share Storage
   - ✅ Table Storage
3. Routes all logs to the centralized Log Analytics Workspace
4. Logs will appear within 5-10 minutes

**Expected output**:
```
Processing storage account: mystorageacct1
Diagnostics enabled for: mystorageacct1
Processing storage account: mystorageacct2
Diagnostics enabled for: mystorageacct2
...
```

---

## Step 7: Generate Test Traffic & Query Logs

### Generate Traffic to Storage Accounts
Connect clients to your storage accounts using TLS 1.0/1.1 clients to generate logs:

```powershell
# Example: Connect to blob storage
$storageAccountName = "makranaappst1"
$context = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount
Get-AzStorageBlob -Container "test" -Context $context
```

### Query TLS Versions in Log Analytics

1. Go to **Azure Portal** → **Log Analytics Workspaces** → `law-tls-capture-central`
2. Click **Logs** (in left menu)
3. Run this KQL query:

```kusto
StorageBlobLogs
| where TimeGenerated > ago(7d)
| project
    StorageAccountName = AccountName,
    TLSVersion = TlsVersion,
    CallerIp = CallerIpAddress
```

This query will show:
- **StorageAccountName**: The storage account being accessed
- **TLSVersion**: The TLS version used by the client (1.0, 1.1, 1.2, etc.)
- **CallerIp**: The IP address of the client

---

## Step 8: Identify & Notify Respective Storage Account Owners

### Analyze Results
1. Review KQL query results from Step 7
2. Identify storage accounts and clients using TLS 1.0 or 1.1:
   - Note the **StorageAccountName** (from query results)
   - Note their **Client IP** and **CallerIp**
   - Document the **access frequency**

### Notify Storage Account Owners
Identify the respective owner/team responsible for each storage account and notify them of the deprecated TLS usage. Provide them with:
- The KQL results showing their non-compliant clients
- Timeline for TLS 1.0/1.1 retirement (February 2026)
- Request to update their applications to use TLS 1.2 or higher

### Monitor & Take Action
**Monitor the client TLS version in LAW and take action for non-compliant clients without any surprises on the retirement date.** Continue tracking until all clients have migrated to TLS 1.2 or higher. This prevents service disruptions when Microsoft enforces the deprecation.

---

## Step 9: Migrate Non-Compliant Storage Accounts

After confirming that TLS 1.0 and 1.1 usage has been identified in Log Analytics (from Step 8), migrate the non-compliant storage accounts to enforce TLS 1.2 or higher:

1. **Coordinate with storage account owners** to ensure their applications have been updated to use TLS 1.2+
2. **Update the minimum TLS version** to TLS 1.2 using Azure CLI or Portal
3. **Schedule migrations** during agreed maintenance windows
4. **Verify** that clients can still connect after the update

```powershell
# Update TLS version using Azure CLI
az storage account update `
  --name "mystorageacct1" `
  --resource-group "rg-TLS-Capture" `
  --min-tls-version TLS1_2
```

---

## Step 10: Clean Up Diagnostic Settings

After analysis is complete, remove diagnostic settings to:
- ✅ Reduce logging costs
- ✅ Clean up infrastructure
- ✅ Stop collecting unnecessary data

```powershell
# Run the removal script
.\RemoveDiag.ps1
```

**What the script does**:
1. Reads storage accounts from `StorageAccounts.xlsx`
2. Disables all diagnostic settings
3. Clears the logs (optional)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Terraform init fails** | Check Azure CLI is logged in: `az login` |
| **Permission denied errors** | Verify Service Principal has Contributor role |
| **DiagEnable.ps1 fails** | Run PowerShell as Administrator; Verify `StorageAccounts.xlsx` exists in project root |
| **No logs appearing in LAW** | Wait 5-10 minutes; Verify diagnostics are enabled in portal |
| **ImportExcel module missing** | Run: `Install-Module -Name ImportExcel -Force` |
| **StorageAccounts.xlsx not found** | Ensure Excel file is saved in the project root directory (same location as DiagEnable.ps1) |

---

## Security Best Practices

⚠️ **Important**:
- ❌ Never commit `terraform.tfvars` to Git
- ❌ Never share `client_secret` in code or messages
- ❌ Rotate service principal secrets regularly
- ✅ Use Azure Key Vault to store secrets
- ✅ Monitor service principal activity in Azure AD
- ✅ Delete test accounts after analysis

---

## Next Steps

1. Let  know if you have any concern. please use below email id to connect. 
2. email : mohsinkhanlpu@gmail.com

✅ Review TLS migration results
✅ Document findings for compliance team
✅ Create migration schedule for remaining accounts
✅ Monitor for any TLS 1.0/1.1 connections after upgrade
✅ Archive logs for audit purposes

---

## Support & Questions

For issues or enhancements, refer to:
- [Azure Cosmos DB & Storage TLS Retirement Docs](https://learn.microsoft.com/azure/)
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/)
- [Log Analytics KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/)

---

**Project Repository**: https://github.com/mohsinkhan7014/azure-storage-tls-retirement-audit

**Last Updated**: January 2026
