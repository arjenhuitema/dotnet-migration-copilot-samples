$ErrorActionPreference = "Stop"
$pubPath = "C:\inetpub\wwwroot\ContosoUniversity"

# Enable detailed error pages for debugging
$webConfig = Join-Path $pubPath "Web.config"
$xml = [xml](Get-Content $webConfig)

# Add/update customErrors mode=Off
$systemWeb = $xml.SelectSingleNode("//system.web")
if ($systemWeb) {
    $customErrors = $systemWeb.SelectSingleNode("customErrors")
    if ($customErrors) {
        $customErrors.SetAttribute("mode", "Off")
    } else {
        $ce = $xml.CreateElement("customErrors")
        $ce.SetAttribute("mode", "Off")
        $systemWeb.AppendChild($ce) | Out-Null
    }
}

# Enable httpErrors passthrough
$systemWebServer = $xml.SelectSingleNode("//system.webServer")
if (-not $systemWebServer) {
    $systemWebServer = $xml.CreateElement("system.webServer")
    $xml.configuration.AppendChild($systemWebServer) | Out-Null
}
$httpErrors = $systemWebServer.SelectSingleNode("httpErrors")
if (-not $httpErrors) {
    $httpErrors = $xml.CreateElement("httpErrors")
    $httpErrors.SetAttribute("errorMode", "Detailed")
    $systemWebServer.AppendChild($httpErrors) | Out-Null
} else {
    $httpErrors.SetAttribute("errorMode", "Detailed")
}

$xml.Save($webConfig)
Write-Output "Enabled detailed errors"

iisreset /restart
Start-Sleep -Seconds 2

# Now test and get the full error
try {
    $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 15
    Write-Output "SUCCESS! HTTP Status: $($response.StatusCode)"
} catch {
    Write-Output "HTTP Error occurred"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        # Extract key error info
        if ($body -match "Could not load file or assembly '([^']+)'") {
            Write-Output "MISSING ASSEMBLY: $($Matches[1])"
        }
        if ($body -match "<pre class=""exceptionMessage"">([^<]+)</pre>") {
            Write-Output "Exception: $($Matches[1])"
        }
        # Write first 2000 chars to help debug
        $clean = $body -replace '<[^>]+>', ' ' -replace '\s+', ' '
        Write-Output $clean.Substring(0, [Math]::Min(2000, $clean.Length))
    } else {
        Write-Output $_.Exception.Message
    }
}

# Also check Windows event log for ASP.NET errors
Write-Output "`n=== Recent Application Event Log Errors ==="
Get-WinEvent -FilterHashtable @{LogName='Application'; Level=2; StartTime=(Get-Date).AddMinutes(-5)} -MaxEvents 3 -ErrorAction SilentlyContinue | ForEach-Object { Write-Output $_.Message.Substring(0, [Math]::Min(500, $_.Message.Length)) }
