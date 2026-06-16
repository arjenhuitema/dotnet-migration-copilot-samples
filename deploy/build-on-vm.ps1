$ErrorActionPreference = "Stop"
$srcRoot = "C:\source\dotnet-migration-copilot-samples-main\ContosoUniversity"

# Copy bootstrap CSS from NuGet packages to Content folder
$bootstrapPkg = Get-ChildItem "$srcRoot\packages\bootstrap*" -Directory | Select-Object -First 1
if ($bootstrapPkg) {
    $bootstrapContent = Join-Path $bootstrapPkg.FullName "content\Content"
    if (Test-Path $bootstrapContent) {
        Write-Output "Copying bootstrap CSS from $bootstrapContent"
        Copy-Item "$bootstrapContent\*" "$srcRoot\Content\" -Force -Recurse
    }
    $bootstrapScripts = Join-Path $bootstrapPkg.FullName "content\Scripts"
    if (Test-Path $bootstrapScripts) {
        Write-Output "Copying bootstrap JS from $bootstrapScripts"
        Copy-Item "$bootstrapScripts\*" "$srcRoot\Scripts\" -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Parse .csproj for all Content Include items and create missing files as placeholders
Write-Output "Checking for missing content files referenced in .csproj..."
$csproj = [xml](Get-Content "$srcRoot\ContosoUniversity.csproj")
$ns = New-Object System.Xml.XmlNamespaceManager($csproj.NameTable)
$ns.AddNamespace("ms", "http://schemas.microsoft.com/developer/msbuild/2003")
$contentItems = $csproj.SelectNodes("//ms:Content[@Include]", $ns)
$missing = 0
$configTransformXml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration xmlns:xdt="http://schemas.microsoft.com/XML-Document-Transform">
</configuration>
"@
foreach ($item in $contentItems) {
    $relPath = $item.GetAttribute("Include")
    $fullPath = Join-Path $srcRoot $relPath
    $needsCreate = (-not (Test-Path $fullPath))
    # Also fix empty .config files from previous runs
    if ((Test-Path $fullPath) -and $relPath -match "\.config$") {
        $size = (Get-Item $fullPath).Length
        if ($size -eq 0) { $needsCreate = $true }
    }
    if ($needsCreate) {
        $dir = Split-Path $fullPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        if ($relPath -match "\.config$") {
            Set-Content -Path $fullPath -Value $configTransformXml -Encoding UTF8
        } else {
            New-Item -ItemType File -Path $fullPath -Force | Out-Null
        }
        $missing++
        Write-Output "  Created/fixed: $relPath"
    }
}
Write-Output "Fixed $missing content items."

# Find MSBuild
$msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuild)) {
    $msbuild = Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio" -Recurse -Filter "MSBuild.exe" | 
        Where-Object { $_.FullName -match "Current\\Bin\\MSBuild\.exe$" } | 
        Select-Object -First 1 -ExpandProperty FullName
}
Write-Output "MSBuild path: $msbuild"

if (-not $msbuild -or -not (Test-Path $msbuild)) {
    Write-Error "MSBuild not found!"
    exit 1
}

# Build and publish
$pubPath = "C:\inetpub\wwwroot\ContosoUniversity"
& $msbuild "$srcRoot\ContosoUniversity.csproj" /p:Configuration=Release /p:DeployOnBuild=true /p:PublishUrl=$pubPath /p:DeployDefaultTarget=WebPublish /p:WebPublishMethod=FileSystem /verbosity:minimal
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed!"; exit 1 }

Write-Output "Build and publish complete!"
Write-Output "Published to: $pubPath"
Get-ChildItem $pubPath | Select-Object Name
