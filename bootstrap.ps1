# Prepare the Windows host for the dotfiles WSL2 workstation. Safe to rerun.
#
# In an Administrator PowerShell:
#   irm https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/bootstrap.ps1 | iex

$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this from an Administrator PowerShell.'
}

function Write-Step($message) {
    Write-Host "`n==> $message" -ForegroundColor Cyan
}

$apps = @(
    'AgileBits.1Password'
    'Tailscale.Tailscale'
    'wez.wezterm'
    'DEVCOM.JetBrainsMonoNerdFont'
    'albertony.npiperelay'
)

foreach ($id in $apps) {
    winget list --exact --id $id --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$id is already installed."
        continue
    }
    Write-Step "Installing $id"
    winget install --exact --id $id --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install $id" }
}

# 1Password and Windows OpenSSH share the same agent pipe; 1Password must own it.
$agent = Get-Service ssh-agent -ErrorAction SilentlyContinue
if ($agent -and $agent.StartType -ne 'Disabled') {
    Write-Step 'Disabling the Windows OpenSSH Authentication Agent'
    Stop-Service ssh-agent -ErrorAction SilentlyContinue
    Set-Service ssh-agent -StartupType Disabled
}

# Windows 11 ships Windows Terminal but can lag far behind; themes need a current release.
winget upgrade --exact --id Microsoft.WindowsTerminal --accept-package-agreements --accept-source-agreements *> $null

# Merge the shared look and keybindings into Windows Terminal. Each machine keeps its own
# profile list, which Terminal generates for installed shells and WSL distributions.
$terminalDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$terminalSettings = Join-Path $terminalDir 'settings.json'
$sharedPath = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'windows-terminal.json' }
$sharedJson = if ($sharedPath -and (Test-Path $sharedPath)) {
    [IO.File]::ReadAllText($sharedPath)
} else {
    (Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/windows-terminal.json').Content
}
$shared = $sharedJson | ConvertFrom-Json
if (Test-Path $terminalSettings) {
    $text = [IO.File]::ReadAllText($terminalSettings)
    # Terminal allows // comment lines; Windows PowerShell's JSON parser does not.
    $settings = ($text -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json
} else {
    New-Item -ItemType Directory -Force $terminalDir | Out-Null
    $text = $null
    $settings = [pscustomobject]@{ profiles = [pscustomobject]@{ list = @() } }
}
foreach ($name in $shared.PSObject.Properties.Name) {
    if ($name -ne 'profiles') { $settings | Add-Member -Force -NotePropertyName $name -NotePropertyValue $shared.$name }
}
$settings.profiles | Add-Member -Force -NotePropertyName defaults -NotePropertyValue $shared.profiles.defaults
$ubuntu = @($settings.profiles.list) | Where-Object { $_.name -eq 'Ubuntu-24.04' -and -not $_.hidden } | Select-Object -First 1
# Terminal resolves a profile name when the generated WSL profile is not saved yet.
$default = if ($ubuntu) { $ubuntu.guid } else { 'Ubuntu-24.04' }
$settings | Add-Member -Force -NotePropertyName defaultProfile -NotePropertyValue $default
$json = $settings | ConvertTo-Json -Depth 32
if ($json -ne $text) {
    Write-Step "Updating Windows Terminal settings"
    if ($null -ne $text) {
        Copy-Item $terminalSettings "$terminalSettings.backup.$(Get-Date -Format yyyyMMddHHmmss)"
    }
    [IO.File]::WriteAllText($terminalSettings, $json, (New-Object Text.UTF8Encoding $false))
}

$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
$desired = "[wsl2]`r`nnetworkingMode=mirrored`r`ndnsTunneling=true`r`nautoProxy=true`r`n"
$current = if (Test-Path $wslConfig) { [IO.File]::ReadAllText($wslConfig) } else { $null }
if ($current -ne $desired) {
    Write-Step "Writing $wslConfig"
    if ($null -ne $current) {
        Copy-Item $wslConfig "$wslConfig.backup.$(Get-Date -Format yyyyMMddHHmmss)"
    }
    [IO.File]::WriteAllText($wslConfig, $desired)
}

$env:WSL_UTF8 = '1'
# Before WSL exists, wsl.exe --list errors; Windows PowerShell 5.1 turns that stderr into an exception.
try {
    $distros = @(wsl.exe --list --quiet 2>$null) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
} catch {
    $distros = @()
}
if ($distros -notcontains 'Ubuntu-24.04') {
    Write-Step 'Installing WSL2 and Ubuntu 24.04'
    wsl.exe --install -d Ubuntu-24.04 --no-launch
    if ($LASTEXITCODE -ne 0) { throw 'wsl --install failed' }
}
Write-Step 'Updating WSL'
wsl.exe --update
wsl.exe --set-default-version 2

$bootstrap = 'bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/bootstrap.sh)"'
Write-Host @"

Windows setup is done. Next:

  1. Reboot if WSL asked for it. If WSL was already running, run: wsl --shutdown
  2. Sign in to 1Password and Tailscale. For SSH keys, enable 1Password's SSH agent
     under Settings > Developer.
  3. Open Ubuntu 24.04, create your Linux user, then run:

     $bootstrap
"@
