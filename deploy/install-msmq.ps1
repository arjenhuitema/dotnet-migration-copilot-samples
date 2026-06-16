$ErrorActionPreference = "Stop"

# Install MSMQ
Write-Output "Installing Message Queuing..."
$result = Install-WindowsFeature -Name MSMQ-Server -IncludeManagementTools
Write-Output "MSMQ Install: $($result.Success) - RestartNeeded: $($result.RestartNeeded)"

# Restart app pool
Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 5

# Test
try {
    $req = [System.Net.HttpWebRequest]::Create("http://localhost/")
    $req.Timeout = 30000
    $resp = $req.GetResponse()
    $stream = $resp.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $body = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    Write-Output "SUCCESS! Length: $($body.Length)"
    if ($body -match "<title>([^<]+)</title>") { Write-Output "Title: $($Matches[1])" }
} catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
        Write-Output "Error: $($clean.Substring(0, [Math]::Min(1000, $clean.Length)))"
    }
}
