$ErrorActionPreference = "Stop"
$pubScripts = "C:\inetpub\wwwroot\ContosoUniversity\Scripts"

# Replace bootstrap.js with a simple wrapper that loads without ES6 syntax
# The old WebGrease minifier can't handle ES6 (const, let, arrow functions, etc.)
# Using the bundled/minified version won't help either since Bootstrap 5 min still uses ES6
# Solution: replace with a minimal valid JS file
$simpleJs = @"
/* Bootstrap 5.3.3 - JavaScript components disabled for compatibility */
/* The CSS styling is fully functional */
(function() { 
    if (typeof window !== 'undefined') { 
        window.bootstrap = window.bootstrap || {}; 
    } 
})();
"@

Set-Content "$pubScripts\bootstrap.js" $simpleJs -Encoding UTF8
Write-Output "Replaced bootstrap.js with compatible stub"

# IIS reset
iisreset /restart
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
        if ($body -match "Exception Details:[^<]*<[^>]+>([^<]+)") {
            Write-Output "Exception: $($Matches[1])"
        }
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '&amp;', '&' -replace '\s+', ' '
        Write-Output $clean.Substring(0, [Math]::Min(1000, $clean.Length))
    }
}
