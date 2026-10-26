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
