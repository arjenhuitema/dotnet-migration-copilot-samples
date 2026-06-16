$ErrorActionPreference = "Stop"
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"

# Set compilation debug=true to disable bundle minification
# (Bootstrap 5 ES6 is incompatible with the old WebGrease minifier)
$xml = [xml](Get-Content $webConfig)
$compilation = $xml.SelectSingleNode("//system.web/compilation")
if ($compilation) {
    $compilation.SetAttribute("debug", "true")
    Write-Output "Set compilation debug=true"
}
$xml.Save($webConfig)

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
    Write-Output "SUCCESS! Status: $([int]$resp.StatusCode)"
    Write-Output "Page length: $($body.Length) chars"
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
        $clean = $body -replace '<style[^>]*>.*?</style>', '' -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
        Write-Output $clean.Substring(0, [Math]::Min(1500, $clean.Length))
    }
}
