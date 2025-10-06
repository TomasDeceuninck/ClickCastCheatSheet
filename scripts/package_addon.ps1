<#
package_addon.ps1

Create a zip suitable for CurseForge packaging or local validation.

Usage examples:
  # From repo root
  pwsh ./scripts/package_addon.ps1

  # Specify output directory
  pwsh ./scripts/package_addon.ps1 -OutDir ./dist

This script will:
- Detect the addon name from the first .toc file found in the repository root (or use -AddonDir)
- Infer a version from the TOC `## Version:` line or from GITHUB_REF tag, falling back to a timestamp
- Copy repository files into a temporary staging folder while excluding common repo folders (.github, docs, .git)
- Produce a zip with top-level folder named after the addon
- Produce a small metadata JSON with the created zip path and SHA1
#>

[CmdletBinding()]
param(
    [string]$AddonDir = "",
    [string]$OutDir = ".",
    [switch]$VerboseOutput
)

Set-StrictMode -Version Latest

$cwd = (Get-Location).Path

if (-not $AddonDir) {
    $toc = Get-ChildItem -Path $cwd -Filter *.toc -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $toc) {
        Write-Error "No .toc file found in repository root. Provide -AddonDir or ensure a .toc file exists."
        exit 1
    }
    $addonName = [System.IO.Path]::GetFileNameWithoutExtension($toc.Name)
} else {
    $addonName = Split-Path -Path $AddonDir -Leaf
    if (-not (Test-Path -Path $AddonDir)) {
        Write-Error "Provided AddonDir '$AddonDir' does not exist."
        exit 1
    }
}

# Get version from TOC if present
$version = $null
if ($toc) {
    $tocContent = Get-Content -Raw -Path $toc.FullName -ErrorAction SilentlyContinue
    if ($tocContent -match '##\s*Version\s*:\s*(.+)') { $version = $matches[1].Trim() }
}

# Fall back to GITHUB_REF tag or timestamp
if (-not $version) {
    if ($env:GITHUB_REF -and $env:GITHUB_REF -like 'refs/tags/*') {
        $version = $env:GITHUB_REF -replace 'refs/tags/', ''
    } else {
        $version = (Get-Date -Format 'yyyyMMddHHmmss')
    }
}

Write-Verbose "Addon name: $addonName"
Write-Verbose "Version: $version"

$tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("pkg_" + [System.Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$staging = Join-Path -Path $tempRoot -ChildPath $addonName
New-Item -ItemType Directory -Path $staging | Out-Null

# Folders/files to ignore when building package
$excludes = @('.git','.github','docs','tests','.vscode','.gitattributes','README.md','LICENSE','pkgmeta.yaml','.pkgmeta')

Get-ChildItem -Path $cwd -Force | ForEach-Object {
    $name = $_.Name
    if ($excludes -contains $name) { return }
    # Copy files/folders into staging under the addon folder
    $dest = Join-Path -Path $staging -ChildPath $name
    try {
        if ($_.PSIsContainer) {
            Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force -ErrorAction Stop
        } else {
            Copy-Item -Path $_.FullName -Destination $staging -Force -ErrorAction Stop
        }
    } catch {
        Write-Warning "Skipping $($_.FullName): $($_.Exception.Message)"
    }
}

# Ensure output directory exists
if (-not (Test-Path -Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$outFileName = "${addonName}-${version}.zip"
$outPath = Join-Path -Path (Resolve-Path $OutDir).Path -ChildPath $outFileName

Write-Output "Creating package: $outPath"

# On Windows PowerShell (5.1) Compress-Archive works; on other environments pwsh has it too.
if (Test-Path -Path $outPath) { Remove-Item -Path $outPath -Force }
Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $outPath -Force

# Compute SHA1
$hash = Get-FileHash -Path $outPath -Algorithm SHA1

$metadata = [PSCustomObject]@{
    name = $addonName
    version = $version
    zip = (Resolve-Path $outPath).Path
    sha1 = $hash.Hash
}

$metaFile = Join-Path -Path (Resolve-Path $OutDir).Path -ChildPath ("${addonName}-${version}.meta.json")
$metadata | ConvertTo-Json -Depth 4 | Out-File -FilePath $metaFile -Encoding utf8

Write-Output "Metadata written to: $metaFile"
Write-Output (ConvertTo-Json $metadata -Depth 4)

Write-Output "Staging folder: $staging"
Write-Output "Temporary files are left under: $tempRoot"

exit 0
