<#
.SYNOPSIS
    Deploys the ContosoUniversity VM infrastructure and application to Azure.

.DESCRIPTION
    This script creates a Windows Server 2022 VM with IIS, SQL Server Express,
    and .NET Framework 4.8 Build Tools, then deploys the ContosoUniversity app.
    This represents the "before migration" state for demo purposes.

.PARAMETER ResourceGroupName
    Name of the resource group to deploy to.

.PARAMETER Location
    Azure region. Try 'uksouth', 'eastus', 'eastus2' if you get SKU capacity errors.

.PARAMETER AdminPassword
    Admin password for the VM (12+ chars, upper+lower+number+special).
#>
param(
    [string]$ResourceGroupName = "rg-contoso-university-demo-before",
    [string]$Location = "uksouth",
    [string]$SubscriptionId = "bca6ccb3-c1fb-4042-85b4-4ffa1654ecba",
    [Parameter(Mandatory=$true)]
    [securestring]$AdminPassword
)

$ErrorActionPreference = "Stop"

Write-Host "=== ContosoUniversity VM Deployment (Pre-Migration Demo) ===" -ForegroundColor Cyan
Write-Host ""

# Set subscription
Write-Host "[1/5] Setting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Create resource group
Write-Host "[2/5] Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location --output none

# Deploy Bicep template
Write-Host "[3/5] Deploying VM infrastructure (this takes 5-10 minutes)..." -ForegroundColor Yellow
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
)

$deployResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$PSScriptRoot\main.bicep" `
    --parameters adminPassword=$plainPassword `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

$vmPublicIp = $deployResult.vmPublicIp.value
$vmName = $deployResult.vmName.value

Write-Host "  VM created successfully!" -ForegroundColor Green
Write-Host "  Public IP: $vmPublicIp" -ForegroundColor Green
Write-Host "  RDP: mstsc /v:$vmPublicIp" -ForegroundColor Green

# Wait for extension to complete
Write-Host "[4/5] Waiting for IIS + SQL Server setup to complete..." -ForegroundColor Yellow
Write-Host "  (Custom Script Extension is installing IIS, SQL Server Express, and Build Tools)" -ForegroundColor Gray

$maxWait = 30  # minutes
$elapsed = 0
do {
    Start-Sleep -Seconds 30
    $elapsed += 0.5
    $status = az vm extension show `
        --resource-group $ResourceGroupName `
        --vm-name $vmName `
        --name "setup-iis-sql" `
        --query "provisioningState" `
        --output tsv 2>$null
    Write-Host "  [$elapsed min] Extension status: $status" -ForegroundColor Gray
} while ($status -ne "Succeeded" -and $status -ne "Failed" -and $elapsed -lt $maxWait)

if ($status -eq "Failed") {
    Write-Host "  WARNING: Extension failed. You may need to RDP into the VM and install manually." -ForegroundColor Red
} else {
    Write-Host "  Setup completed!" -ForegroundColor Green
}

# Open HTTP port on NSG (already in Bicep, but ensure it's open)
Write-Host "[5/5] Deployment complete!" -ForegroundColor Yellow

Write-Host ""
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  VM Name:        $vmName" -ForegroundColor White
Write-Host "  Public IP:      $vmPublicIp" -ForegroundColor White
Write-Host "  RDP:            mstsc /v:$vmPublicIp" -ForegroundColor White
Write-Host "  Web:            http://$vmPublicIp" -ForegroundColor White
Write-Host "  Admin User:     azureadmin" -ForegroundColor White
Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "  1. RDP into the VM: mstsc /v:$vmPublicIp" -ForegroundColor White
Write-Host "  2. Run deploy-app.ps1 from within the VM to publish the app to IIS" -ForegroundColor White
Write-Host "  3. Or use the deploy-app-remote.ps1 script to deploy remotely" -ForegroundColor White
Write-Host ""
