$ErrorActionPreference = "Stop"
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"

# Verify the published Web.config has debug=true
$content = Get-Content $webConfig -Raw
Write-Output "=== compilation element ==="
if ($content -match '(<compilation[^>]+>)') { Write-Output $Matches[1] }

Write-Output "`n=== Connection string ==="
if ($content -match 'connectionString="([^"]+)"') { Write-Output $Matches[1] }

# Full IIS reset (not just app pool restart)
iisreset /stop
Start-Sleep -Seconds 2

# Clear ASP.NET temp files to remove cached bundles
$tempPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Temporary ASP.NET Files"
if (Test-Path $tempPath) {
    Remove-Item "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output "`nCleared ASP.NET temp files"
}

iisreset /start
Start-Sleep -Seconds 5

# Test
try {
    $req = [System.Net.HttpWebRequest]::Create("http://localhost/")
    $req.Timeout = 60000
    $resp = $req.GetResponse()
    $stream = $resp.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $body = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    Write-Output "`nSUCCESS! Status: $([int]$resp.StatusCode)"
    Write-Output "Page length: $($body.Length) chars"
    if ($body -match "<title>([^<]+)</title>") { Write-Output "Title: $($Matches[1])" }
} catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
        Write-Output "`nHTTP $([int]$resp.StatusCode)"
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        # Extract the key error
        if ($body -match "Exception Details:[^<]*<[^>]+>([^<]+)") {
            Write-Output "Exception: $($Matches[1])"
        }
        if ($body -match "Source File:[^<]*<[^>]+>\s*([^\n<]+)") {
            Write-Output "Source: $($Matches[1])"
        }
        if ($body -match "Line:\s*<[^>]+>\s*(\d+)") {
            Write-Output "Line: $($Matches[1])"
        }
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '&amp;', '&' -replace '\s+', ' '
        Write-Output "`nFull error: $($clean.Substring(0, [Math]::Min(800, $clean.Length)))"
    }
}
