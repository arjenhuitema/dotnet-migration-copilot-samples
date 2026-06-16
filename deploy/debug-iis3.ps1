$ErrorActionPreference = "Stop"
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"

# Enable detailed errors
$xml = [xml](Get-Content $webConfig)
$sw = $xml.SelectSingleNode("//system.web")
$ce = $sw.SelectSingleNode("customErrors")
if (-not $ce) {
    $ce = $xml.CreateElement("customErrors")
    $sw.AppendChild($ce) | Out-Null
}
$ce.SetAttribute("mode", "Off")

$sws = $xml.SelectSingleNode("//system.webServer")
if (-not $sws) {
    $sws = $xml.CreateElement("system.webServer")
    $xml.configuration.AppendChild($sws) | Out-Null
}
$he = $sws.SelectSingleNode("httpErrors")
if (-not $he) {
    $he = $xml.CreateElement("httpErrors")
    $sws.AppendChild($he) | Out-Null
}
$he.SetAttribute("errorMode", "Detailed")
$xml.Save($webConfig)
Write-Output "Enabled detailed errors"

# Restart app pool
Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 3

# Test
try {
    $req = [System.Net.HttpWebRequest]::Create("http://localhost/")
    $req.Timeout = 15000
    $resp = $req.GetResponse()
    Write-Output "SUCCESS! Status: $($resp.StatusCode)"
    $resp.Close()
} catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
        Write-Output "Error body:"
        Write-Output $clean.Substring(0, [Math]::Min(2500, $clean.Length))
    } else {
        Write-Output "No response: $($_.Exception.Message)"
    }
}
