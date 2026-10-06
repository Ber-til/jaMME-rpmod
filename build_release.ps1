# Builds a Windows x86 release of jaMME and packages it as a zip.
#
#   .\build_release.ps1            configure (first run only), build, package
#   .\build_release.ps1 -Clean     wipe the build directory first
#
# Output: out\package\ (unpacked release) and out\jamme-windows-x86.zip
# The tracked build\ template is copied, never modified.

param(
	[switch]$Clean
)

$ErrorActionPreference = 'Stop'

$root     = $PSScriptRoot
$buildDir = Join-Path $root 'out\release'
$stageDir = Join-Path $root 'out\package'
$zipPath  = Join-Path $root 'out\jamme-windows-x86.zip'
$binDir   = Join-Path $buildDir 'Release'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

function Invoke-Checked {
	$exe, $rest = $args
	& $exe @rest
	if ($LASTEXITCODE -ne 0) { throw "'$exe' failed with exit code $LASTEXITCODE" }
}

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
	throw 'cmake was not found in PATH. Install CMake or add it to PATH.'
}

if ($Clean -and (Test-Path $buildDir)) {
	Step 'Removing previous build'
	Remove-Item -Recurse -Force $buildDir
}

if (-not (Test-Path (Join-Path $buildDir 'CMakeCache.txt'))) {
	Step 'Configuring (32-bit, newest installed Visual Studio)'
	# the project still declares cmake_minimum_required(3.1), which current CMake rejects without this
	Invoke-Checked cmake -S $root -B $buildDir -A Win32 '-DCMAKE_POLICY_VERSION_MINIMUM=3.5'
}

Step 'Building Release'
Invoke-Checked cmake --build $buildDir --config Release '--' /m /v:minimal

Step 'Staging release files'
if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
Copy-Item -Recurse (Join-Path $root 'build') $stageDir
# launchers for other platforms
Remove-Item (Join-Path $stageDir 'start_jaMME.sh'), (Join-Path $stageDir 'start_jaMME.command') -ErrorAction SilentlyContinue

$engineFiles = 'jamme.exe', 'rd-jamme_x86.dll'
$modFiles    = 'cgamex86.dll', 'uix86.dll', 'jampgamex86.dll'
foreach ($f in $engineFiles) { Copy-Item (Join-Path $binDir $f) $stageDir }
foreach ($f in $modFiles)    { Copy-Item (Join-Path $binDir $f) (Join-Path $stageDir 'mme') }

# same stamp the CI writes into the readme
$revision = (git -C $root rev-parse --short HEAD 2>$null)
if (-not $revision) { $revision = 'unknown' }
elseif (git -C $root status --porcelain --untracked-files=no 2>$null) { $revision += '-dirty' }
$readme = Join-Path $stageDir 'mme\readme.txt'
$encoding = [System.Text.Encoding]::Default
$text = [System.IO.File]::ReadAllText($readme, $encoding)
$text = $text -replace 'Date: .*', ('Date: ' + (Get-Date -Format 'dd.MM.yyyy'))
$text = $text -replace 'Revision: .*', ('Revision: ' + $revision)
[System.IO.File]::WriteAllText($readme, $text, $encoding)

Step 'Creating zip'
if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
# tar.exe ships with Windows 10+ and writes portable zip paths, unlike Compress-Archive on PowerShell 5.1
$entries = Get-ChildItem $stageDir | ForEach-Object { $_.Name }
Invoke-Checked tar -a -c -f $zipPath -C $stageDir @entries

Write-Host "`nRelease ready (revision $revision):" -ForegroundColor Green
Write-Host "  folder: $stageDir"
Write-Host "  zip:    $zipPath"
