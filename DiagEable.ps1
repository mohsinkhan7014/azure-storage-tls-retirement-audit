# VARIABLES
$excelPath = "D:\Daily-Update\TLS-Capture-Porject\StorageAccounts.xlsx"
$lawName   = "law-tls-capture-central"
$lawRG     = "rg-TLS-Capture"
$diagName  = "stg-diag-tls-logs"

# Get Log Analytics Workspace
$law = Get-AzOperationalInsightsWorkspace -Name $lawName -ResourceGroupName $lawRG

# Import Excel
$storageAccounts = Import-Excel -Path $excelPath

foreach ($sa in $storageAccounts) {

    Write-Host "Processing storage account:" $sa.StorageAccountName -ForegroundColor Cyan

    $storage = Get-AzStorageAccount `
        -ResourceGroupName $sa.ResourceGroupName `
        -Name $sa.StorageAccountName

    $services = @(
        @{ Name = "blob";  ResourceId = "$($storage.Id)/blobServices/default"  },
        @{ Name = "file";  ResourceId = "$($storage.Id)/fileServices/default"  },
        @{ Name = "queue"; ResourceId = "$($storage.Id)/queueServices/default" },
        @{ Name = "table"; ResourceId = "$($storage.Id)/tableServices/default"  }
    )

    foreach ($svc in $services) {

        $diagName = "stg-diag-$($svc.Name)-tls"

        Write-Host "  Enabling diagnostics for $($svc.Name) service" -ForegroundColor Yellow

        New-AzDiagnosticSetting `
            -Name $diagName `
            -ResourceId $svc.ResourceId `
            -WorkspaceId $law.ResourceId `
            -Log @(
                @{ Category = "StorageRead";   Enabled = $true },
                @{ Category = "StorageWrite";  Enabled = $true },
                @{ Category = "StorageDelete"; Enabled = $true }
            )
    }

    Write-Host "Diagnostics enabled for all services:" $sa.StorageAccountName -ForegroundColor Green
}