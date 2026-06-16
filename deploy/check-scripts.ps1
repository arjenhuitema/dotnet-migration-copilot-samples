$ErrorActionPreference = "Stop"
$srcRoot = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity"
$pubPath = "C:\inetpub\wwwroot\ContosoUniversity"

# Check bootstrap files in published Scripts folder
Write-Output "=== Published Scripts folder bootstrap files ==="
Get-ChildItem "$pubPath\Scripts\bootstrap*" | Select-Object Name, Length

# Check source Scripts folder
Write-Output "`n=== Source Scripts folder bootstrap files ==="
Get-ChildItem "$srcRoot\Scripts\bootstrap*" | Select-Object Name, Length

# Check if the NuGet package has the actual JS files
$bootstrapPkg = Get-ChildItem "$srcRoot\packages\bootstrap*" -Directory | Select-Object -First 1
Write-Output "`n=== Bootstrap package contents ==="
Get-ChildItem $bootstrapPkg.FullName -Recurse -Filter "*.js" | Select-Object FullName, Length

# The issue: bootstrap 5.3.3 NuGet package content\Scripts has the JS files
$contentScripts = Join-Path $bootstrapPkg.FullName "content\Scripts"
if (Test-Path $contentScripts) {
    Write-Output "`n=== content\Scripts ==="
    Get-ChildItem $contentScripts | Select-Object Name, Length
}

# Copy real JS files to published folder
$distJs = Join-Path $bootstrapPkg.FullName "dist\js"
if (Test-Path $distJs) {
    Write-Output "`n=== dist\js files ==="
    Get-ChildItem $distJs | Select-Object Name, Length
}
