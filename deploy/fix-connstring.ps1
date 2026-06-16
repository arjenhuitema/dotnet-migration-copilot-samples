$ErrorActionPreference = "Stop"
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"

# Fix connection string - SQL is default instance, not SQLEXPRESS
$content = Get-Content $webConfig -Raw
$content = $content -replace 'Data Source=\.\\SQLEXPRESS', 'Data Source=.'
Set-Content $webConfig $content -Encoding UTF8
Write-Output "Fixed connection string to use default instance"

# Grant the IIS app pool identity access to SQL Server
$sqlCmd = @"
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'IIS APPPOOL\ContosoUniversityPool')
    CREATE LOGIN [IIS APPPOOL\ContosoUniversityPool] FROM WINDOWS;
EXEC sp_addsrvrolemember 'IIS APPPOOL\ContosoUniversityPool', 'sysadmin';
"@
try {
    Invoke-Sqlcmd -ServerInstance "." -Query $sqlCmd
    Write-Output "Granted sysadmin to app pool identity"
} catch {
    Write-Output "SQL permission note: $($_.Exception.Message)"
    # Try alternative - use sa
    try {
        Invoke-Sqlcmd -ServerInstance "." -Username "sa" -Password "P@ssw0rd123!" -Query $sqlCmd
        Write-Output "Granted via sa"
    } catch {
        Write-Output "Also failed via sa: $($_.Exception.Message)"
    }
}

# Restart app pool
Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 5

# Test with good timeout
try {
    $r = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 30
    Write-Output "`nSUCCESS! Status: $($r.StatusCode)"
    Write-Output "Length: $($r.Content.Length) chars"
    if ($r.Content -match "<title>([^<]+)</title>") { Write-Output "Title: $($Matches[1])" }
} catch {
    Write-Output "`nError: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
        Write-Output $clean.Substring(0, [Math]::Min(1000, $clean.Length))
    }
}
