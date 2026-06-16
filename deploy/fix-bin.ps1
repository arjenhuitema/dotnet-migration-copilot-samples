$ErrorActionPreference = "Stop"
$pubBin = "C:\inetpub\wwwroot\ContosoUniversity\bin"
$srcRoot = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity"

# Check what's in the published bin
Write-Output "=== Published bin contents ==="
Get-ChildItem $pubBin -Filter "*.dll" | Select-Object Name | Sort-Object Name

Write-Output "`n=== Looking for Microsoft.Bcl.HashCode in packages ==="
Get-ChildItem "$srcRoot\packages" -Recurse -Filter "Microsoft.Bcl.HashCode.dll" | Select-Object FullName

Write-Output "`n=== Looking for all missing assemblies in packages ==="
# Get all DLLs from packages that might be needed
$packageDlls = Get-ChildItem "$srcRoot\packages" -Recurse -Filter "*.dll" | Where-Object { $_.Directory.Name -match "net4|netstandard" }
$binDlls = Get-ChildItem $pubBin -Filter "*.dll" | Select-Object -ExpandProperty Name

$copied = 0
foreach ($dll in $packageDlls) {
    if ($dll.Name -notin $binDlls) {
        # Prefer net48 > net472 > net461 > netstandard2.0
        # Only copy if not already there
        if (-not (Test-Path (Join-Path $pubBin $dll.Name))) {
            Copy-Item $dll.FullName $pubBin -Force
            $copied++
        }
    }
}
Write-Output "Copied $copied additional DLLs from packages to bin"

# Also check the build output bin for any DLLs not in publish
$buildBin = "$srcRoot\bin"
if (Test-Path $buildBin) {
    $buildDlls = Get-ChildItem $buildBin -Filter "*.dll" -ErrorAction SilentlyContinue
    foreach ($dll in $buildDlls) {
        if (-not (Test-Path (Join-Path $pubBin $dll.Name))) {
            Copy-Item $dll.FullName $pubBin -Force
            Write-Output "Copied from build bin: $($dll.Name)"
        }
    }
}

iisreset /restart
Start-Sleep -Seconds 2
try {
    $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 15
    Write-Output "`nHTTP Status: $($response.StatusCode)"
    Write-Output "Page length: $($response.Content.Length) chars"
} catch {
    Write-Output "`nError: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        Write-Output "Status: $($_.Exception.Response.StatusCode)"
    }
}
