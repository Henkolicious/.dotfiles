#Requires -Version 7
<#
.SYNOPSIS
    Puts the configs under home/ where Windows looks for them. Idempotent.

.DESCRIPTION
    The upstream repo this is modelled on links its files with home-manager's
    mkOutOfStoreSymlink, so the real file stays in the repo and ~ only points at it.
    Windows has no unprivileged `ln -s`: a real symlink needs Developer Mode or an
    elevated shell. Directory junctions need neither and are indistinguishable for
    this purpose, so every directory is junctioned.

    Two single files cannot be junctioned, so they are pointed at instead:
      - the PowerShell profile, via a one-line stub that dot-sources the repo copy
      - starship.toml, via the STARSHIP_CONFIG user environment variable

    Anything real found in a target path is moved aside to <name>.bak-<timestamp>
    rather than deleted.
#>

$ErrorActionPreference = 'Stop'

$repo = $PSScriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Backup-Existing {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $backup = "$Path.bak-$stamp"
    Move-Item -LiteralPath $Path -Destination $backup
    Write-Host "  moved aside -> $backup" -ForegroundColor DarkYellow
}

function Set-EnvPointer {
    # For the single files that cannot be junctioned: the program is told where its
    # config lives instead of the config being moved to where it looks.
    param([string]$Name, [string]$Value)

    Write-Host "$(Split-Path -Leaf $Value) -> $Value"
    if ([Environment]::GetEnvironmentVariable($Name, 'User') -eq $Value) {
        Write-Host "  $Name already set" -ForegroundColor DarkGray
    }
    else {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Write-Host "  $Name set (takes effect in new shells)" -ForegroundColor Green
    }
    Set-Item -Path "Env:$Name" -Value $Value
}

function Link-Directory {
    param([string]$Target, [string]$Source)

    $name = Split-Path -Leaf $Target
    Write-Host "$name -> $Source"

    $existing = Get-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    if ($existing) {
        # ReparsePoint covers both a junction and a symlink; either one already
        # pointing at the repo is left alone.
        if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            if ($existing.Target -eq $Source) {
                Write-Host "  already linked" -ForegroundColor DarkGray
                return
            }
            Remove-Item -LiteralPath $Target -Force   # drops the link, not its contents
        }
        else {
            Backup-Existing $Target
        }
    }

    $parent = Split-Path -Parent $Target
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    New-Item -ItemType Junction -Path $Target -Value $Source | Out-Null
    Write-Host "  linked" -ForegroundColor Green
}

# --- WezTerm -----------------------------------------------------------------
Link-Directory -Target (Join-Path $HOME '.config\wezterm') -Source (Join-Path $repo 'home\.config\wezterm')

# $HOME\.wezterm.lua is consulted before $HOME\.config\wezterm\wezterm.lua, so a
# leftover copy there would silently win over the linked one.
$legacyWezterm = Join-Path $HOME '.wezterm.lua'
if (Test-Path -LiteralPath $legacyWezterm) {
    Write-Host '.wezterm.lua (superseded by .config\wezterm\wezterm.lua)'
    Backup-Existing $legacyWezterm
}

# --- Neovim ------------------------------------------------------------------
# Neovim on Windows reads $LOCALAPPDATA\nvim, not ~/.config/nvim.
Link-Directory -Target (Join-Path $env:LOCALAPPDATA 'nvim') -Source (Join-Path $repo 'home\.config\nvim')

# --- starship ----------------------------------------------------------------
Set-EnvPointer -Name 'STARSHIP_CONFIG' -Value (Join-Path $repo 'home\.config\starship.toml')

# The copy starship would otherwise have found by default, left in place, would be a
# second source of truth that nothing reads.
$defaultStarship = Join-Path $HOME '.config\starship.toml'
if (Test-Path -LiteralPath $defaultStarship) { Backup-Existing $defaultStarship }

# --- herdr -------------------------------------------------------------------
Set-EnvPointer -Name 'HERDR_CONFIG_PATH' -Value (Join-Path $repo 'home\.config\herdr\config.toml')

# Same reasoning as starship. herdr keeps sockets, logs and session state in this
# directory alongside the config, which is why the directory itself is not junctioned.
$defaultHerdr = Join-Path $env:APPDATA 'herdr\config.toml'
if (Test-Path -LiteralPath $defaultHerdr) { Backup-Existing $defaultHerdr }

# --- PowerShell profile ------------------------------------------------------
$profilePath = $PROFILE.CurrentUserCurrentHost
$profileSource = Join-Path $repo 'home\.config\powershell\profile.ps1'
$stub = ". `"$profileSource`""
Write-Host "$(Split-Path -Leaf $profilePath) -> $profileSource"
if ((Test-Path -LiteralPath $profilePath) -and ((Get-Content -LiteralPath $profilePath -Raw).Trim() -eq $stub)) {
    Write-Host '  stub already in place' -ForegroundColor DarkGray
}
else {
    Backup-Existing $profilePath
    $parent = Split-Path -Parent $profilePath
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    Set-Content -LiteralPath $profilePath -Value $stub -Encoding utf8NoBOM
    Write-Host '  stub written' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done. Open a new WezTerm window to pick everything up.' -ForegroundColor Cyan
