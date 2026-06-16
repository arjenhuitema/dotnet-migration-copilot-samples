$ErrorActionPreference = "Stop"

# Find sqlcmd
$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $sqlcmd) {
    $sqlcmd = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter "sqlcmd.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}
Write-Output "sqlcmd: $sqlcmd"

if (-not $sqlcmd) {
    Write-Output "sqlcmd not found, trying to add SQL tools to PATH"
    $toolsPath = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter "sqlcmd.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($toolsPath) {
        $sqlcmd = $toolsPath.FullName
    } else {
        Write-Output "Cannot find sqlcmd.exe anywhere!"
        exit 1
    }
}

# Grant sysadmin to IIS app pool
$query = @"
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'IIS APPPOOL\ContosoUniversityPool')
    CREATE LOGIN [IIS APPPOOL\ContosoUniversityPool] FROM WINDOWS;
EXEC sp_addsrvrolemember 'IIS APPPOOL\ContosoUniversityPool', 'sysadmin';
GO
"@

$result = & $sqlcmd -S "." -E -C -Q $query 2>&1
Write-Output "SQL result: $result"

# Also try granting via NT AUTHORITY\NETWORK SERVICE as fallback
$query2 = @"
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'NT AUTHORITY\NETWORK SERVICE')
    CREATE LOGIN [NT AUTHORITY\NETWORK SERVICE] FROM WINDOWS;
EXEC sp_addsrvrolemember 'NT AUTHORITY\NETWORK SERVICE', 'sysadmin';
GO
"@
$result2 = & $sqlcmd -S "." -E -C -Q $query2 2>&1
Write-Output "NS result: $result2"

# Restart app pool and test
Import-Module WebAdministration

# Also add TrustServerCertificate to connection string for SQL 2025
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"
$content = Get-Content $webConfig -Raw
if ($content -notmatch "TrustServerCertificate") {
    $content = $content -replace '(MultipleActiveResultSets=True)', '$1;TrustServerCertificate=True'
    Set-Content $webConfig $content -Encoding UTF8
    Write-Output "Added TrustServerCertificate=True to connection string"
}

Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 5

try {
    $r = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 30
    Write-Output "`nSUCCESS! Status: $($r.StatusCode)"
    Write-Output "Length: $($r.Content.Length) chars"
    if ($r.Content -match "<title>([^<]+)</title>") { Write-Output "Title: $($Matches[1])" }
} catch {
    Write-Output "`nApp Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
        Write-Output $clean.Substring(0, [Math]::Min(1000, $clean.Length))
    }
}
