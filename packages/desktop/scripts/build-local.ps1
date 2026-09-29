# Builds this checkout's desktop app and installs it into a local folder with a desktop
# shortcut. Settings and sign-ins are shared with the official app (same data folders).
# -Update merges upstream/main into the current branch first; -SkipWeb/-SkipMpv skip steps.
param(
  [string]$Dest = (Join-Path $env:LOCALAPPDATA 'AIOStreams-ozel'),
  [switch]$Update,
  [switch]$SkipWeb,
  [switch]$SkipMpv
)
$ErrorActionPreference = 'Stop'

$env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' +
  [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';C:\Program Files\7-Zip'

$desktop = Split-Path -Parent $PSScriptRoot
$repo = Split-Path -Parent (Split-Path -Parent $desktop)

function Invoke-Step([string]$name, [scriptblock]$block) {
  Write-Host "==> $name" -ForegroundColor Cyan
  & $block
  if ($LASTEXITCODE) { throw "$name failed (exit $LASTEXITCODE)" }
}

Push-Location $repo
try {
  if ($Update) {
    Invoke-Step 'git fetch upstream' { git fetch upstream }
    Invoke-Step 'git merge upstream/main' { git merge --no-edit upstream/main }
    Invoke-Step 'pnpm install' { pnpm install }
  }

  $dll = Join-Path $desktop 'vendor/x86_64/libmpv-2.dll'
  $pinned = (Get-Content (Join-Path $desktop 'libmpv.pin') | Where-Object { $_ -match '^tag=' }) -replace '^tag=', ''
  $versionFile = Join-Path $desktop 'vendor/x86_64/libmpv.version'
  $have = if (Test-Path $versionFile) { (Get-Content $versionFile).Trim() } else { '' }
  if (-not $SkipMpv -and (-not (Test-Path $dll) -or $have -ne $pinned)) {
    Invoke-Step 'fetch libmpv' { & (Join-Path $PSScriptRoot 'fetch-libmpv.ps1') -Arch x86_64 }
  }

  if (-not $SkipWeb) {
    Invoke-Step 'build web' { pnpm -F @aiostreams/jellyfin-web build:standalone }
  }

  Push-Location $desktop
  try { Invoke-Step 'cargo build' { cargo build --release } } finally { Pop-Location }

  if (Get-Process aiostreams-desktop -ErrorAction SilentlyContinue |
      Where-Object { $_.Path -like "$Dest*" }) {
    throw 'The app is running from the install folder; close it and run again.'
  }

  Write-Host "==> install to $Dest" -ForegroundColor Cyan
  New-Item -ItemType Directory -Force $Dest | Out-Null
  Copy-Item (Join-Path $desktop 'target/release/aiostreams-desktop.exe') $Dest -Force
  Copy-Item $dll $Dest -Force
  $web = Join-Path $Dest 'web'
  if (Test-Path $web) { Remove-Item $web -Recurse -Force }
  Copy-Item (Join-Path $repo 'packages/jellyfin-web/dist-standalone') $web -Recurse

  $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AIOStreams (ozel).lnk'
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($lnk)
  $shortcut.TargetPath = Join-Path $Dest 'aiostreams-desktop.exe'
  $shortcut.WorkingDirectory = $Dest
  $shortcut.Save()

  Write-Host "Done. Shortcut: $lnk" -ForegroundColor Green
} finally {
  Pop-Location
}
