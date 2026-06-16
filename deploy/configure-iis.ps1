$ErrorActionPreference = "Stop"

Import-Module WebAdministration

# Remove default website
if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
    Remove-Website -Name "Default Web Site"
    Write-Output "Removed Default Web Site"
}

# Create app pool for .NET 4.0
if (-not (Test-Path "IIS:\AppPools\ContosoUniversityPool")) {
    New-WebAppPool -Name "ContosoUniversityPool"
}
Set-ItemProperty "IIS:\AppPools\ContosoUniversityPool" -Name "managedRuntimeVersion" -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\ContosoUniversityPool" -Name "managedPipelineMode" -Value "Integrated"
Write-Output "App pool configured"

# Create website
$sitePath = "C:\inetpub\wwwroot\ContosoUniversity"
if (Get-Website -Name "ContosoUniversity" -ErrorAction SilentlyContinue) {
    Remove-Website -Name "ContosoUniversity"
}
New-Website -Name "ContosoUniversity" -PhysicalPath $sitePath -ApplicationPool "ContosoUniversityPool" -Port 80
Write-Output "Website created on port 80"

# Grant IIS_IUSRS permissions to app folder
$acl = Get-Acl $sitePath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "ReadAndExecute,ListDirectory", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule)
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS_IUSRS", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($rule2)
Set-Acl $sitePath $acl
Write-Output "Permissions set"

# Update Web.config connection string to use local SQL Express
$webConfig = Join-Path $sitePath "Web.config"
$xml = [xml](Get-Content $webConfig)
$connStrings = $xml.SelectSingleNode("//connectionStrings")
if ($connStrings) {
    foreach ($add in $connStrings.SelectNodes("add")) {
        if ($add.name -eq "SchoolContext") {
            $add.connectionString = "Data Source=.\SQLEXPRESS;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True"
            Write-Output "Updated SchoolContext connection string to SQL Express"
        }
    }
} else {
    # Create connectionStrings section
    $connStrings = $xml.CreateElement("connectionStrings")
    $add = $xml.CreateElement("add")
    $add.SetAttribute("name", "SchoolContext")
    $add.SetAttribute("connectionString", "Data Source=.\SQLEXPRESS;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True")
    $add.SetAttribute("providerName", "System.Data.SqlClient")
    $connStrings.AppendChild($add) | Out-Null
    $xml.configuration.AppendChild($connStrings) | Out-Null
    Write-Output "Added SchoolContext connection string"
}
$xml.Save($webConfig)
Write-Output "Web.config saved"

# Grant SQL Express permissions to the app pool identity
$sqlCmd = "IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'IIS APPPOOL\ContosoUniversityPool') CREATE LOGIN [IIS APPPOOL\ContosoUniversityPool] FROM WINDOWS; IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'IIS APPPOOL\ContosoUniversityPool') BEGIN USE [master]; CREATE LOGIN [IIS APPPOOL\ContosoUniversityPool] FROM WINDOWS END;"
try {
    Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Query $sqlCmd -ErrorAction SilentlyContinue
} catch {
    Write-Output "Note: Could not create SQL login (may need manual setup): $_"
}

# Grant sysadmin for simplicity in demo
try {
    Invoke-Sqlcmd -ServerInstance ".\SQLEXPRESS" -Query "IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name='IIS APPPOOL\ContosoUniversityPool') CREATE LOGIN [IIS APPPOOL\ContosoUniversityPool] FROM WINDOWS; EXEC sp_addsrvrolemember 'IIS APPPOOL\ContosoUniversityPool', 'sysadmin';" -ErrorAction SilentlyContinue
    Write-Output "SQL login configured for app pool"
} catch {
    Write-Output "SQL login config note: $_"
}

# Restart IIS
iisreset /restart
Write-Output "IIS restarted. Site should be available at http://localhost"

# Quick test
try {
    $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 10
    Write-Output "HTTP Status: $($response.StatusCode)"
} catch {
    Write-Output "Test request result: $_"
}
