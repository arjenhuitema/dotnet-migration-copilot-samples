<#
.SYNOPSIS
    Deploys the ContosoUniversity app to the VM via RDP/WinRM.
    Run this script FROM the VM after RDP'ing in, or use deploy-app-remote.ps1.

.DESCRIPTION
    Builds and deploys the ASP.NET MVC app to IIS on the local machine.
    Prerequisites: IIS, .NET 4.8, SQL Server Express (installed by the VM setup).
#>

$ErrorActionPreference = "Stop"
$appPath = "C:\inetpub\wwwroot\ContosoUniversity"
$sourcePath = "C:\ContosoUniversity"

Write-Host "=== Deploying ContosoUniversity to IIS ===" -ForegroundColor Cyan

# Step 1: Ensure source is available
if (-not (Test-Path $sourcePath)) {
    Write-Host "ERROR: Source code not found at $sourcePath" -ForegroundColor Red
    Write-Host "Please copy the ContosoUniversity folder to C:\ContosoUniversity first." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "From your local machine, use:" -ForegroundColor Yellow
    Write-Host "  Copy-Item -Path '.\ContosoUniversity' -Destination '\\<VM-IP>\C$\ContosoUniversity' -Recurse" -ForegroundColor Gray
    exit 1
}

# Step 2: Restore NuGet packages
Write-Host "[1/4] Restoring NuGet packages..." -ForegroundColor Yellow
$nugetUrl = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$nugetPath = "C:\nuget.exe"
if (-not (Test-Path $nugetPath)) {
    Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetPath
}
& $nugetPath restore "$sourcePath\ContosoUniversity.sln"

# Step 3: Build the project
Write-Host "[2/4] Building the project..." -ForegroundColor Yellow
$msbuildPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
    -latest -requires Microsoft.Component.MSBuild -find "MSBuild\**\Bin\MSBuild.exe" 2>$null

if (-not $msbuildPath) {
    # Try VS Build Tools path
    $msbuildPath = Get-ChildItem -Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" `
        -Recurse -Filter "MSBuild.exe" -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -like "*\Bin\MSBuild.exe" } | 
        Select-Object -First 1 -ExpandProperty FullName
}

if (-not $msbuildPath) {
    Write-Host "ERROR: MSBuild not found. Ensure VS Build Tools are installed." -ForegroundColor Red
    exit 1
}

& $msbuildPath "$sourcePath\ContosoUniversity.csproj" `
    /p:Configuration=Release `
    /p:DeployOnBuild=true `
    /p:PublishUrl=$appPath `
    /p:DeployDefaultTarget=WebPublish `
    /p:WebPublishMethod=FileSystem `
    /verbosity:minimal

# Step 4: Configure IIS site
Write-Host "[3/4] Configuring IIS..." -ForegroundColor Yellow
Import-Module WebAdministration

# Remove default site if exists
if (Get-Website -Name "Default Web Site" -ErrorAction SilentlyContinue) {
    Remove-Website -Name "Default Web Site"
}

# Create app pool
if (-not (Test-Path "IIS:\AppPools\ContosoUniversity")) {
    New-WebAppPool -Name "ContosoUniversity"
}
Set-ItemProperty "IIS:\AppPools\ContosoUniversity" -Name "managedRuntimeVersion" -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\ContosoUniversity" -Name "enable32BitAppOnWin64" -Value $false

# Create website
if (Get-Website -Name "ContosoUniversity" -ErrorAction SilentlyContinue) {
    Remove-Website -Name "ContosoUniversity"
}
New-Website -Name "ContosoUniversity" `
    -Port 80 `
    -PhysicalPath $appPath `
    -ApplicationPool "ContosoUniversity"

# Step 5: Update connection string for local SQL Express
Write-Host "[4/4] Updating connection string..." -ForegroundColor Yellow
$webConfigPath = "$appPath\Web.config"
if (Test-Path $webConfigPath) {
    $xml = [xml](Get-Content $webConfigPath)
    $connStr = $xml.configuration.connectionStrings.add | Where-Object { $_.name -eq "DefaultConnection" }
    if ($connStr) {
        $connStr.connectionString = "Data Source=.\MSSQLSERVER;Initial Catalog=ContosoUniversityNoAuthEFCore;Integrated Security=True;MultipleActiveResultSets=True"
    }
    $xml.Save($webConfigPath)
}

# Grant IIS app pool access to the app folder
$acl = Get-Acl $appPath
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    "IIS AppPool\ContosoUniversity", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl $appPath $acl

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "  The app is now running at: http://localhost" -ForegroundColor White
Write-Host "  From outside: http://<VM-Public-IP>" -ForegroundColor White
Write-Host ""
