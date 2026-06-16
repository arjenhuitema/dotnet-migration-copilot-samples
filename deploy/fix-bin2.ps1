$ErrorActionPreference = "Stop"
$pkgRoot = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity\packages"
$pubBin = "C:\inetpub\wwwroot\ContosoUniversity\bin"

# Copy the specific missing DLL
$src = "$pkgRoot\Microsoft.Bcl.HashCode.1.1.1\lib\net461\Microsoft.Bcl.HashCode.dll"
if (Test-Path $src) {
    Copy-Item $src $pubBin -Force
    Write-Output "Copied Microsoft.Bcl.HashCode.dll"
} else {
    Write-Output "ERROR: $src not found"
}

# Copy ALL net461 DLLs from packages that aren't already in the bin
$existingDlls = Get-ChildItem $pubBin -Filter "*.dll" | Select-Object -ExpandProperty Name
$net461Dlls = Get-ChildItem $pkgRoot -Recurse -Filter "*.dll" | Where-Object { $_.Directory.Name -eq "net461" -and $_.Name -notin $existingDlls }
foreach ($dll in $net461Dlls) {
    Copy-Item $dll.FullName $pubBin -Force
    Write-Output "Copied net461: $($dll.Name)"
}

# Also copy net472/net48 for DLLs not already present
$existingDlls = Get-ChildItem $pubBin -Filter "*.dll" | Select-Object -ExpandProperty Name
$net48Dlls = Get-ChildItem $pkgRoot -Recurse -Filter "*.dll" | Where-Object { ($_.Directory.Name -eq "net472" -or $_.Directory.Name -eq "net48") -and $_.Name -notin $existingDlls }
foreach ($dll in $net48Dlls) {
    Copy-Item $dll.FullName $pubBin -Force
    Write-Output "Copied net48/472: $($dll.Name)"
}

# Restart IIS
iisreset /restart
Start-Sleep -Seconds 3

# Test
try {
    $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 15
    Write-Output "SUCCESS! HTTP Status: $($response.StatusCode)"
    Write-Output "Page length: $($response.Content.Length) chars"
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $body = $reader.ReadToEnd()
        # Show just the error message, not full HTML
        if ($body -match "Could not load file or assembly '([^']+)'") {
            Write-Output "Missing assembly: $($Matches[1])"
        } elseif ($body -match "<title>([^<]+)</title>") {
            Write-Output "Page title: $($Matches[1])"
        }
        Write-Output "First 500 chars: $($body.Substring(0, [Math]::Min(500, $body.Length)))"
    }
}
