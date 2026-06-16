$ErrorActionPreference = "Stop"
$srcRoot = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity"
$pubPath = "C:\inetpub\wwwroot\ContosoUniversity"
$msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"

# Clean previous publish
if (Test-Path $pubPath) { Remove-Item $pubPath -Recurse -Force }
Write-Output "Cleaned publish folder"

# Clean build output
$objPath = Join-Path $srcRoot "obj"
if (Test-Path $objPath) { Remove-Item $objPath -Recurse -Force }
Write-Output "Cleaned obj folder"

# Rebuild and publish fresh
Write-Output "Building..."
& $msbuild "$srcRoot\ContosoUniversity.csproj" /p:Configuration=Release /p:DeployOnBuild=true /p:PublishUrl=$pubPath /p:DeployDefaultTarget=WebPublish /p:WebPublishMethod=FileSystem /verbosity:minimal /t:Rebuild
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed!"; exit 1 }
Write-Output "Build and publish complete"

# Now ONLY add the one missing DLL: Microsoft.Bcl.HashCode.dll
$hashCodeDll = "$srcRoot\packages\Microsoft.Bcl.HashCode.1.1.1\lib\net461\Microsoft.Bcl.HashCode.dll"
if (Test-Path $hashCodeDll) {
    Copy-Item $hashCodeDll "$pubPath\bin\" -Force
    Write-Output "Added Microsoft.Bcl.HashCode.dll to bin"
}

# Update connection string in published Web.config 
$webConfig = Join-Path $pubPath "Web.config"
$content = Get-Content $webConfig -Raw
$content = $content -replace 'Data Source=\(LocalDb\)\\MSSQLLocalDB', 'Data Source=.\SQLEXPRESS'
Set-Content $webConfig $content -Encoding UTF8
Write-Output "Updated connection string to SQL Express"

# Restart app pool
Import-Module WebAdministration
Restart-WebAppPool "ContosoUniversityPool"
Start-Sleep -Seconds 3

# Test
try {
    $response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 15
    Write-Output "SUCCESS! HTTP Status: $($response.StatusCode)"
    Write-Output "Page length: $($response.Content.Length) chars"
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $reader.Close()
        $clean = $body -replace '<[^>]+>', '' -replace '&nbsp;', ' ' -replace '&#39;', "'" -replace '\s+', ' '
        Write-Output $clean.Substring(0, [Math]::Min(1500, $clean.Length))
    }
}
