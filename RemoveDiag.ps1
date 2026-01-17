# VARIABLES
$excelPath = "D:\Daily-Update\TLS-Capture-Porject\StorageAccounts.xlsx"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " TLS Diagnostic Settings Deletion Script" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

# FIRST CONFIRMATION
$confirm1 = Read-Host "Do you want to DELETE TLS diagnostic settings from listed storage accounts? (yes/no)"

if ($confirm1.ToLower() -ne "yes") {
    Write-Host "Operation cancelled at first confirmation." -ForegroundColor Yellow
    return
}

# SECOND CONFIRMATION (STRONG)
$confirm2 = Read-Host "FINAL CONFIRMATION: Type YES to permanently delete diagnostic settings"

if ($confirm2 -ne "YES") {
    Write-Host "Operation cancelled at final confirmation." -ForegroundColor Yellow
    return
}

Write-Host ""
Write-Host "Confirmed twice. Proceeding with deletion..." -ForegroundColor Red
Write-Host ""

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
        @{ Name = "table"; ResourceId = "$($storage.Id)/tableServices/default" }
    )

    foreach ($svc in $services) {

        $diagName = "stg-diag-$($svc.Name)-tls"

        Write-Host "  Checking diagnostics for $($svc.Name) service" -ForegroundColor Yellow

        $diag = Get-AzDiagnosticSetting -ResourceId $svc.ResourceId -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq $diagName }

        if ($diag) {
            Remove-AzDiagnosticSetting `
                -ResourceId $svc.ResourceId `
                -Name $diagName

            Write-Host "    Deleted: $diagName" -ForegroundColor Green
        }
        else {
            Write-Host "    Not found: $diagName (skipped)" -ForegroundColor DarkGray
        }
    }

    Write-Host "Cleanup completed for:" $sa.StorageAccountName -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "===================================================" -ForegroundColor Green
Write-Host " TLS diagnostic settings deletion COMPLETED" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
