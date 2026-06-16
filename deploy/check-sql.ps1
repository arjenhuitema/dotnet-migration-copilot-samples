$ErrorActionPreference = "Stop"

# Check SQL Server Express status
$svc = Get-Service -Name "MSSQL`$SQLEXPRESS" -ErrorAction SilentlyContinue
if ($svc) {
    Write-Output "SQL Express service: $($svc.Status)"
    if ($svc.Status -ne "Running") {
        Start-Service $svc
        Write-Output "Started SQL Express"
    }
} else {
    Write-Output "SQL Express service not found! Checking all SQL services:"
    Get-Service | Where-Object { $_.DisplayName -match "SQL" } | Select-Object Name, Status, DisplayName
}

# Test SQL connectivity
Write-Output "`nTesting SQL connection..."
try {
    $conn = New-Object System.Data.SqlClient.SqlConnection("Data Source=.\SQLEXPRESS;Integrated Security=True;Connection Timeout=5")
    $conn.Open()
    Write-Output "SQL connection successful! Server version: $($conn.ServerVersion)"
    $conn.Close()
} catch {
    Write-Output "SQL connection failed: $($_.Exception.Message)"
    # Try other instance names
    Write-Output "`nTrying default instance..."
    try {
        $conn = New-Object System.Data.SqlClient.SqlConnection("Data Source=.;Integrated Security=True;Connection Timeout=5")
        $conn.Open()
        Write-Output "Default instance works! Version: $($conn.ServerVersion)"
        $conn.Close()
    } catch {
        Write-Output "Default instance also failed: $($_.Exception.Message)"
    }
}

# Check what connection string the app has
$webConfig = "C:\inetpub\wwwroot\ContosoUniversity\Web.config"
$content = Get-Content $webConfig -Raw
if ($content -match 'connectionString="([^"]+)"') {
    Write-Output "`nApp connection string: $($Matches[1])"
}

# Try with longer timeout
Write-Output "`nTesting app with 60s timeout..."
try {
    $r = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 60
    Write-Output "Status: $($r.StatusCode)"
    Write-Output "Length: $($r.Content.Length)"
} catch {
    Write-Output "Error: $($_.Exception.Message)"
}
