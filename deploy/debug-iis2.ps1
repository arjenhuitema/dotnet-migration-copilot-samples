$ErrorActionPreference = "Stop"
$pubBin = "C:\inetpub\wwwroot\ContosoUniversity\bin"
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"

# Check assembly version of Microsoft.Bcl.HashCode
$dllPath = Join-Path $pubBin "Microsoft.Bcl.HashCode.dll"
if (Test-Path $dllPath) {
    $asm = [System.Reflection.Assembly]::LoadFrom($dllPath)
    Write-Output "Microsoft.Bcl.HashCode version: $($asm.GetName().Version)"
} else {
    Write-Output "Microsoft.Bcl.HashCode.dll NOT in bin!"
}

# Check Web.config for binding redirects
$xml = [xml](Get-Content $webConfig)
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace("asm", "urn:schemas-microsoft-com:asm.v1")
$redirects = $xml.SelectNodes("//asm:dependentAssembly", $ns)
Write-Output "`nExisting binding redirects ($($redirects.Count)):"
foreach ($r in $redirects) {
    $identity = $r.SelectSingleNode("asm:assemblyIdentity", $ns)
    $binding = $r.SelectSingleNode("asm:bindingRedirect", $ns)
    if ($identity -and $binding) {
        Write-Output "  $($identity.GetAttribute('name')): $($binding.GetAttribute('oldVersion')) -> $($binding.GetAttribute('newVersion'))"
    }
}

# Check if there's a binding redirect for Microsoft.Bcl.HashCode
$hasHashCodeRedirect = $false
foreach ($r in $redirects) {
    $identity = $r.SelectSingleNode("asm:assemblyIdentity", $ns)
    if ($identity -and $identity.GetAttribute("name") -eq "Microsoft.Bcl.HashCode") {
        $hasHashCodeRedirect = $true
    }
}
Write-Output "`nHas Microsoft.Bcl.HashCode redirect: $hasHashCodeRedirect"

# Try to use .NET HttpWebRequest for better error capture
Write-Output "`n=== Testing with HttpWebRequest ==="
try {
    $req = [System.Net.HttpWebRequest]::Create("http://localhost/")
    $req.Timeout = 15000
    $resp = $req.GetResponse()
    Write-Output "Status: $($resp.StatusCode)"
    $resp.Close()
} catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if ($resp) {
        Write-Output "Status: $($resp.StatusCode) ($([int]$resp.StatusCode))"
        $stream = $resp.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()
        if ($body.Length -gt 0) {
            $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
            Write-Output "Body ($($body.Length) chars): $($clean.Substring(0, [Math]::Min(3000, $clean.Length)))"
        } else {
            Write-Output "Empty response body"
        }
    } else {
        Write-Output "No response: $($_.Exception.Message)"
    }
}

# Check Event Viewer
Write-Output "`n=== ASP.NET Event Log ==="
Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=(Get-Date).AddMinutes(-5)} -MaxEvents 5 -ErrorAction SilentlyContinue | Where-Object { $_.Message -match "error|exception|fail" } | ForEach-Object {
    Write-Output "[$($_.TimeCreated)] $($_.Message.Substring(0, [Math]::Min(800, $_.Message.Length)))"
}
