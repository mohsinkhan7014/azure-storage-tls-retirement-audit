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
- ✅ 3 Storage Accounts with different TLS versions:
  - `makranaappst1` with TLS 1.0
  - `makranaappst2` with TLS 1.1
  - Optional: Add your own storage accounts

**Output**: Note the Log Analytics Workspace ID and storage account names.

---

## Step 4: Identify Non-Compliant Storage Accounts

### Option A: Use the Sample Accounts
The Terraform deployment creates 3 test storage accounts. Use these for initial testing.

### Option B: Use Your Own Storage Accounts
If you have existing storage accounts with TLS 1.0 or 1.1, list them in the Excel file.

1. **Open `StorageAccounts.xlsx`** (or create from template)
2. **Fill in your storage accounts**:

| StorageAccountName | ResourceGroupName | TLSVersion |
|---|---|---|
| mystorageacct1 | rg-production | TLS1_0 |
| mystorageacct2 | rg-production | TLS1_1 |
| mystorageacct3 | rg-compliance | TLS1_0 |

3. **Save the file** in the project root directory

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
| where Protocol has_any ("TLS1.0", "TLS1.1")
| summarize Count = count() by ClientIP, Protocol, CallerIPAddress
| order by Count desc
```

**Alternative queries**:

```kusto
# All storage operations with TLS version
StorageBlobLogs
| where isnotempty(Protocol)
| summarize Count = count() by Protocol
| order by Count desc

# Queue operations
StorageQueueLogs
| where Protocol has_any ("TLS1.0", "TLS1.1")
| summarize Count = count() by ClientIP, Protocol

# File share operations
StorageFileLogs
| where Protocol has_any ("TLS1.0", "TLS1.1")
| summarize Count = count() by ClientIP, Protocol

# Table storage operations
StorageTableLogs
| where Protocol has_any ("TLS1.0", "TLS1.1")
| summarize Count = count() by ClientIP, Protocol
```

---

## Step 8: Identify & Notify Non-Compliant Clients

### Analyze Results
1. Review KQL query results
2. Identify clients/applications using TLS 1.0 or 1.1:
   - Note their **Client IP** and **CallerIPAddress**
   - Identify the **owners** of those applications
   - Document the **access frequency**

### Notify Stakeholders
Send notifications to application owners:

📧 **Sample Message**:
```
Subject: Azure Storage TLS 1.0/1.1 Deprecation - Action Required

Your application is using deprecated TLS versions to connect to Azure Storage.
Microsoft will retire TLS 1.0 and 1.1 support in February 2026.

Required Action:
- Update your application to use TLS 1.2 or higher
- Target Date: [date before Feb 2026]
- Testing Window: [test date]

Contact: [your-team-info]
```

---

## Step 9: Update Storage Account TLS Versions

### Plan the Migration
1. **Coordinate with application owners** to ensure they've updated their code
2. **Test with TLS 1.2 only** in non-production accounts first
3. **Schedule migrations** during maintenance windows

### Update TLS Version

#### Option A: Using Terraform
Edit `storageAccount.tf` and update the `min_tls_version`:

```hcl
resource "azurerm_storage_account" "storageaccount1" {
  ...
  min_tls_version = "TLS1_2"  # Updated from TLS1_0
  ...
}

# Apply changes
terraform apply -auto-approve
```

#### Option B: Using Azure CLI
```powershell
az storage account update `
  --name "mystorageacct1" `
  --resource-group "rg-TLS-Capture" `
  --min-tls-version TLS1_2
```

#### Option C: Using Azure Portal
1. Go to **Storage Account** → **Configuration**
2. Set **Minimum TLS version** to **1.2**
3. Click **Save**

### Verify Migration
```powershell
# Check current TLS setting
az storage account show `
  --name "mystorageacct1" `
  --resource-group "rg-TLS-Capture" `
  --query minimumTlsVersion
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
| **DiagEnable.ps1 fails** | Run PowerShell as Administrator; Verify `StorageAccounts.xlsx` exists |
| **No logs appearing in LAW** | Wait 5-10 minutes; Verify diagnostics are enabled in portal |
| **TLS version won't update** | Check no active connections to storage; Re-run `terraform apply` |
| **ImportExcel module missing** | Run: `Install-Module -Name ImportExcel -Force` |

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

1. ✅ Review TLS migration results
2. ✅ Document findings for compliance team
3. ✅ Create migration schedule for remaining accounts
4. ✅ Monitor for any TLS 1.0/1.1 connections after upgrade
5. ✅ Archive logs for audit purposes

---

## Support & Questions

For issues or enhancements, refer to:
- [Azure Cosmos DB & Storage TLS Retirement Docs](https://learn.microsoft.com/azure/)
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/)
- [Log Analytics KQL Reference](https://learn.microsoft.com/azure/data-explorer/kusto/)

---

**Project Repository**: https://github.com/mohsinkhan7014/azure-storage-tls-retirement-audit

**Last Updated**: January 2026
