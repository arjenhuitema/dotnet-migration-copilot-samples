$ErrorActionPreference = "Stop"

# Re-enable detailed errors (was reset by clean rebuild)
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"
$xml = [xml](Get-Content $webConfig)
$sw = $xml.SelectSingleNode("//system.web")
$ce = $sw.SelectSingleNode("customErrors")
if (-not $ce) { $ce = $xml.CreateElement("customErrors"); $sw.AppendChild($ce) | Out-Null }
$ce.SetAttribute("mode", "Off")
$sws = $xml.SelectSingleNode("//system.webServer")
$he = $sws.SelectSingleNode("httpErrors")
if (-not $he) { $he = $xml.CreateElement("httpErrors"); $sws.AppendChild($he) | Out-Null }
$he.SetAttribute("errorMode", "Detailed")
$xml.Save($webConfig)

# Restart app pool
Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 5

# Test with detailed error capture
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
        Write-Output "HTTP $([int]$resp.StatusCode)"
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        if ($body.Length -gt 0) {
            $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
            Write-Output $clean.Substring(0, [Math]::Min(2000, $clean.Length))
        } else {
            Write-Output "Empty body - checking event log"
            Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=(Get-Date).AddMinutes(-2)} -MaxEvents 2 -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Output $_.Message.Substring(0, [Math]::Min(500, $_.Message.Length))
            }
        }
    } else {
        Write-Output "No response: $($_.Exception.Message)"
    }
} catch {
    Write-Output "Other error: $($_.Exception.Message)"
}
