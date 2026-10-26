# Merge the shared Windows Terminal look, keybindings, and profile icons into this
# machine's settings. Each machine keeps the profile list Terminal generates for it.
# Needs no administrator rights. Safe to rerun; bootstrap.sh reruns it once WSL has
# registered Ubuntu so the Ubuntu profile picks up its icon.
#
#   irm https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/windows-terminal.ps1 | iex

param([string]$Source = 'https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/windows-terminal')

$ErrorActionPreference = 'Stop'

function Get-SharedFile($name, $destination) {
    if ($Source -match '^https://') {
        Invoke-WebRequest -UseBasicParsing "$Source/$name" -OutFile $destination
    } else {
        Copy-Item (Join-Path $Source $name) $destination
    }
}

$terminalDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$settingsPath = Join-Path $terminalDir 'settings.json'
$iconDir = Join-Path $terminalDir 'icons'
New-Item -ItemType Directory -Force $iconDir | Out-Null

$sharedPath = Join-Path $env:TEMP 'windows-terminal-shared.json'
Get-SharedFile 'settings.json' $sharedPath
$shared = [IO.File]::ReadAllText($sharedPath) | ConvertFrom-Json
Remove-Item $sharedPath

$icons = 'ubuntu', 'powershell', 'cmd', 'azure', 'developer', 'terminal'
foreach ($icon in $icons) {
    Get-SharedFile "icons/$icon.png" (Join-Path $iconDir "$icon.png")
}

function Get-ProfileIcon($entry) {
    $name = "$($entry.name)"
    $icon = switch -Regex ($name) {
        '^Developer ' { 'developer'; break }
        'PowerShell' { 'powershell'; break }
        '^Command Prompt' { 'cmd'; break }
        'Azure' { 'azure'; break }
        'Ubuntu' { 'ubuntu'; break }
        default { 'terminal' }
    }
    Join-Path $iconDir "$icon.png"
}

if (Test-Path $settingsPath) {
    $text = [IO.File]::ReadAllText($settingsPath)
    # Terminal allows // comment lines; Windows PowerShell's JSON parser does not.
    $settings = ($text -split "`n" | Where-Object { $_ -notmatch '^\s*//' }) -join "`n" | ConvertFrom-Json
} else {
    $text = $null
    $settings = [pscustomobject]@{ profiles = [pscustomobject]@{ list = @() } }
}
foreach ($name in $shared.PSObject.Properties.Name) {
    if ($name -ne 'profiles') { $settings | Add-Member -Force -NotePropertyName $name -NotePropertyValue $shared.$name }
}
$defaults = $shared.profiles.defaults
$defaults | Add-Member -Force -NotePropertyName icon -NotePropertyValue (Join-Path $iconDir 'terminal.png')
$settings.profiles | Add-Member -Force -NotePropertyName defaults -NotePropertyValue $defaults

# WSL publishes each distribution's profile as a fragment with a machine-specific GUID and
# its own color scheme and font. List those profiles so the shared look and icons override them.
$list = [Collections.ArrayList]@(@($settings.profiles.list) | Where-Object { $_ })
$fragments = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments'
if (Test-Path $fragments) {
    foreach ($file in Get-ChildItem $fragments -Recurse -Filter *.json) {
        $fragment = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
        foreach ($fragmentProfile in @($fragment.profiles) | Where-Object { $_.guid -and $_.name }) {
            $entry = $list | Where-Object { $_.guid -eq $fragmentProfile.guid } | Select-Object -First 1
            if (-not $entry) {
                $entry = [pscustomobject]@{ guid = $fragmentProfile.guid; name = $fragmentProfile.name; source = $file.Directory.Name; hidden = $false }
                [void]$list.Add($entry)
            }
            $entry | Add-Member -Force -NotePropertyName colorScheme -NotePropertyValue $defaults.colorScheme
            $entry | Add-Member -Force -NotePropertyName font -NotePropertyValue $defaults.font
        }
    }
}
foreach ($entry in $list) {
    $entry | Add-Member -Force -NotePropertyName icon -NotePropertyValue (Get-ProfileIcon $entry)
}
$settings.profiles | Add-Member -Force -NotePropertyName list -NotePropertyValue $list.ToArray()

# Prefer WSL's own profile; it hides the older generated one on machines that have both.
$ubuntu = @($list | Where-Object { $_.name -eq 'Ubuntu-24.04' -and -not $_.hidden } | Sort-Object { $_.source -ne 'Microsoft.WSL' })[0]
# Terminal resolves a profile name when the generated WSL profile is not saved yet.
$default = if ($ubuntu) { $ubuntu.guid } else { 'Ubuntu-24.04' }
$settings | Add-Member -Force -NotePropertyName defaultProfile -NotePropertyValue $default

$json = $settings | ConvertTo-Json -Depth 32
if ($json -ne $text) {
    Write-Host "Updating Windows Terminal settings: $settingsPath"
    if ($null -ne $text) {
        Copy-Item $settingsPath "$settingsPath.backup.$(Get-Date -Format yyyyMMddHHmmss)"
    }
    [IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding $false))
} else {
    Write-Host 'Windows Terminal settings are already up to date.'
}
