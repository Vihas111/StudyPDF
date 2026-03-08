param(
[string]$Version = "1.2.0",
[switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
Set-Location $root

$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$stageDir = Join-Path $root "build\installer\stage"
$distDir = Join-Path $root "build\installer\dist"
$tempIss = Join-Path $root "build\installer\updater_temp.iss"

$downloaderDir = Join-Path $root "pesu_course_downloader"
$stageDownloaderDir = Join-Path $stageDir "pesu_course_downloader"

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
Copy-Item (Join-Path $releaseDir "*") $stageDir -Recurse -Force

if (-not (Test-Path $downloaderDir)) {
throw "Downloader repo not found at: $downloaderDir"
}

Write-Host "Staging downloader scripts..."

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
Copy-Item $source $stageDownloaderDir -Force
}
}

New-Item -ItemType Directory -Path (Join-Path $stageDownloaderDir "downloads") -Force | Out-Null

Write-Host "Generating updater installer script..."

$issContent = @"
#define MyAppName "StudyPDF"
#define MyAppVersion "$Version"
#define MyAppExeName "studypdf.exe"
#define MySourceRoot "stage"

[Setup]
AppId={{1EFD9A25-7C8A-4E0D-9B6E-BF73A0E216B4}}
AppName={#MyAppName} Updater
AppVersion={#MyAppVersion}

DefaultDirName={localappdata}\Programs\StudyPDF
UsePreviousAppDir=yes
DisableDirPage=yes

OutputDir=dist
OutputBaseFilename=StudyPDF-Updater-v{#MyAppVersion}

Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest

CreateUninstallRegKey=no
UpdateUninstallLogAppName=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#MySourceRoot}*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch StudyPDF $Version now"; Flags: nowait postinstall skipifsilent
"@

Set-Content $tempIss $issContent

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
throw "Inno Setup compiler (ISCC.exe) not found"
}

Write-Host "Building updater installer..."
& $isccPath $tempIss

if ($LASTEXITCODE -ne 0) {
throw "Updater build failed."
}

Write-Host ""
Write-Host "Updater created in:"
Write-Host $distDir
