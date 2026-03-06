param(
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
Set-Location $root

$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$stageDir = Join-Path $root "build\installer\stage"
$distDir = Join-Path $root "build\installer\dist"
$downloaderDir = Join-Path $root "pesu_course_downloader"
$stageDownloaderDir = Join-Path $stageDir "pesu_course_downloader"
$issFile = Join-Path $root "installer\studypdf.iss"

if (-not $SkipBuild) {
  Write-Host "Building Windows release..."
  flutter build windows --release
}

if (-not (Test-Path $releaseDir)) {
  throw "Release output not found at: $releaseDir"
}

if (Test-Path $stageDir) {
  Remove-Item $stageDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stageDir | Out-Null
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

Write-Host "Staging app binaries..."
Copy-Item -Path (Join-Path $releaseDir "*") -Destination $stageDir -Recurse -Force

if (-not (Test-Path $downloaderDir)) {
  throw "Downloader repo not found at: $downloaderDir"
}

Write-Host "Staging downloader scripts (excluding local data)..."
New-Item -ItemType Directory -Path $stageDownloaderDir -Force | Out-Null

$downloaderWhitelist = @(
  ".gitignore",
  "LICENSE",
  "README.md",
  "requirements.txt",
  "interactive_download.py",
  "pdf_dedup.py",
  "studypdf_bridge.py"
)

foreach ($item in $downloaderWhitelist) {
  $source = Join-Path $downloaderDir $item
  if (Test-Path $source) {
    Copy-Item -Path $source -Destination $stageDownloaderDir -Force
  }
}

# Ensure runtime-generated folders exist but ship empty.
New-Item -ItemType Directory -Path (Join-Path $stageDownloaderDir "downloads") -Force | Out-Null

$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
$isccPath = $null
if ($iscc) {
  $isccPath = $iscc.Source
}
if (-not $isccPath) {
  $defaultIscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
  if (Test-Path $defaultIscc) {
    $isccPath = $defaultIscc
  }
}

if (-not $isccPath) {
  Write-Host ""
  Write-Host "Stage is ready, but Inno Setup compiler was not found."
  Write-Host "Install Inno Setup 6, then run:"
  Write-Host "  `"$issFile`" with ISCC.exe"
  Write-Host ""
  Write-Host "Staged files: $stageDir"
  exit 0
}

Write-Host "Building installer with Inno Setup..."
& $isccPath $issFile

Write-Host ""
Write-Host "Installer created in: $distDir"
