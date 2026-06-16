$ErrorActionPreference = "Stop"
$pkgRoot = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity\packages"
$pubBin = "C:\inetpub\wwwroot\ContosoUniversity\bin"
$buildBin = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity\bin"

# Find SNI native DLLs
Write-Output "Looking for SNI DLLs..."
$sniFiles = Get-ChildItem $pkgRoot -Recurse -Filter "Microsoft.Data.SqlClient.SNI*" | Where-Object { $_.Extension -eq ".dll" }
foreach ($f in $sniFiles) {
    Write-Output "  Found: $($f.FullName)"
}

# Copy the x64 native DLL to bin folder
$sniX64 = $sniFiles | Where-Object { $_.Name -eq "Microsoft.Data.SqlClient.SNI.x64.dll" } | Select-Object -First 1
if ($sniX64) {
    Copy-Item $sniX64.FullName $pubBin -Force
    Write-Output "Copied $($sniX64.Name) from packages"
} else {
    # Try build bin
    $sniBuild = Get-ChildItem $buildBin -Filter "Microsoft.Data.SqlClient.SNI.x64.dll" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($sniBuild) {
        Copy-Item $sniBuild.FullName $pubBin -Force
        Write-Output "Copied $($sniBuild.Name) from build bin"
    } else {
        Write-Output "ERROR: SNI DLL not found anywhere!"
    }
}

# Also copy x86 just in case
$sniX86 = $sniFiles | Where-Object { $_.Name -eq "Microsoft.Data.SqlClient.SNI.x86.dll" } | Select-Object -First 1
if ($sniX86) {
    Copy-Item $sniX86.FullName $pubBin -Force
    Write-Output "Copied $($sniX86.Name)"
}

# Verify
Write-Output "`nSNI DLLs in published bin:"
Get-ChildItem $pubBin -Filter "*SNI*" | Select-Object Name, Length

# Restart and test
Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 3

try {
    $req = [System.Net.HttpWebRequest]::Create("http://localhost/")
    $req.Timeout = 15000
    $resp = $req.GetResponse()
    Write-Output "`nSUCCESS! Status: $($resp.StatusCode)"
    $stream = $resp.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $body = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    Write-Output "Page length: $($body.Length) chars"
    if ($body -match "<title>([^<]+)</title>") { Write-Output "Title: $($Matches[1])" }
} catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        if ($body -match "Unable to load|Could not load|cannot find") {
            $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
            Write-Output "Still failing: $($clean.Substring(0, [Math]::Min(500, $clean.Length)))"
        } else {
            $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
            Write-Output "Error: $($clean.Substring(0, [Math]::Min(1000, $clean.Length)))"
        }
    }
}
