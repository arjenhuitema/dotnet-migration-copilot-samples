Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 5
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
        # Get just the text content
        $clean = $body -replace '<style[^>]*>.*?</style>', '' -replace '<script[^>]*>.*?</script>', '' -replace '<[^>]+>', "`n" -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '&amp;', '&' -replace '\n\s*\n', "`n" -replace '^\s+', ''
        Write-Output $clean.Substring(0, [Math]::Min(3000, $clean.Length))
    }
}
