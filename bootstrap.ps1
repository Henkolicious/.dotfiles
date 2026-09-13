#Requires -Version 7
<#
.SYNOPSIS
    Installs the programs the configs under home/ are written for. Idempotent.

.DESCRIPTION
    install.ps1 puts configuration where Windows looks for it; this puts the programs
    that read that configuration on the machine first. On a fresh install the order is:

      1. pwsh -NoProfile -File .\bootstrap.ps1     (this file -- the programs)
      2. pwsh -NoProfile -File .\install.ps1       (the links)
      3. bash ~/.dotfiles/install.sh               (inside WSL, once it exists)

    Run it from PowerShell 7. If the machine has no pwsh yet, Windows PowerShell 5.1
    can bootstrap that one package first:

        winget install --id Microsoft.PowerShell --exact

    winget elevates itself for the packages that install machine-wide, so this script
    does not ask for an elevated shell up front; expect a UAC prompt or several.

    Everything here is skipped when it is already present, so a re-run after a partial
    one costs nothing but the version checks.

.PARAMETER InstallWsl
    Also enable WSL2 and install Ubuntu-24.04. Off by default: it needs an elevated
    shell and a reboot, which is a decision rather than a step.

.PARAMETER SkipDotnetTools
    Leave the global dotnet tools alone. They are the only entry here that belongs to
    the work rather than to the shell.
#>
[CmdletBinding()]
param(
    [switch]$InstallWsl,
    [switch]$SkipDotnetTools
)

$ErrorActionPreference = 'Stop'

function info { param([string]$m) Write-Host $m }
function same { param([string]$m) Write-Host "  $m" -ForegroundColor DarkGray }
function did  { param([string]$m) Write-Host "  $m" -ForegroundColor Green }
function warn { param([string]$m) Write-Host "  $m" -ForegroundColor DarkYellow }

# --- winget ------------------------------------------------------------------
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is not on PATH. Install "App Installer" from the Microsoft Store, then re-run.'
}

# Ordered so the shell and the terminal come up first: a run interrupted halfway still
# leaves something usable to finish from.
#
# Probe is the command the package puts on PATH, and it is checked before winget's own
# inventory, because that inventory answers a narrower question than "is this here".
# Node on this machine is registered as OpenJS.NodeJS.22 carrying a 24.x, so a
# `winget list --id OpenJS.NodeJS` finds nothing and a second copy would get installed
# over it. Where a package has no distinctive command -- the SDK is behind the same
# `dotnet` as every other SDK -- the probe is empty and winget decides alone.
$packages = @(
    @{ Id = 'Microsoft.PowerShell';       Probe = 'pwsh';     Why = 'PowerShell 7 -- the shell WezTerm starts by default' }
    @{ Id = 'wez.wezterm';                Probe = 'wezterm';  Why = 'the terminal' }
    @{ Id = 'Starship.Starship';          Probe = 'starship'; Why = 'the prompt, shared with the WSL side' }
    @{ Id = 'Neovim.Neovim';              Probe = 'nvim';     Why = 'the editor $EDITOR points at' }
    @{ Id = 'Git.Git';                    Probe = 'git';      Why = 'git, and the bash the installers can run under' }
    @{ Id = 'GitHub.cli';                 Probe = 'gh';       Why = 'gh' }
    @{ Id = 'BurntSushi.ripgrep.MSVC';    Probe = 'rg';       Why = 'what snacks.picker greps with' }
    @{ Id = 'sharkdp.fd';                 Probe = 'fd';       Why = 'what snacks.picker finds files with' }
    @{ Id = 'junegunn.fzf';               Probe = 'fzf';      Why = 'fuzzy finder' }
    @{ Id = 'jqlang.jq';                  Probe = 'jq';       Why = 'jq' }
    @{ Id = 'JesseDuffield.lazygit';      Probe = 'lazygit';  Why = 'lazygit' }
    @{ Id = 'Herdr.Herdr.Preview';        Probe = 'herdr';    Why = 'herdr -- install.ps1 points HERDR_CONFIG_PATH at its config' }
    @{ Id = 'Microsoft.VisualStudioCode'; Probe = 'code';     Why = 'VS Code' }
    @{ Id = 'OpenJS.NodeJS';              Probe = 'node';     Why = 'Node -- the Vite frontend and the npm-installed agents' }
    @{ Id = 'Microsoft.DotNet.SDK.10';    Probe = '';         Why = '.NET 10 SDK' }
    @{ Id = 'Docker.DockerDesktop';       Probe = 'docker';   Why = 'Docker -- the Postgres container the apphost starts' }
)

info 'winget packages'
foreach ($pkg in $packages) {
    info "  $($pkg.Id)  ($($pkg.Why))"

    if ($pkg.Probe -and (Get-Command $pkg.Probe -ErrorAction SilentlyContinue)) {
        same "already installed ($($pkg.Probe) is on PATH)"
        continue
    }

    winget list --id $pkg.Id --exact --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) {
        same 'already installed'
        continue
    }

    winget install --id $pkg.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 0) { did 'installed' } else { warn "winget exited $LASTEXITCODE -- install it by hand" }
}

# --- PowerShell modules ------------------------------------------------------
# The profile imports both before starship, so a missing one breaks the prompt rather
# than degrading it.
info ''
info 'PowerShell modules'

# PSReadLine ships in the box. PredictionViewStyle ListView, which the profile sets,
# arrived in 2.2 -- so this only installs when what is already there predates that.
# Installing regardless would shadow a newer in-box copy with an older gallery one.
info '  PSReadLine'
$psrl = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
if ($psrl -and $psrl.Version -ge [version]'2.2.0') {
    same "already present ($($psrl.Version))"
}
else {
    Install-Module -Name PSReadLine -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
    did 'installed'
}

info '  Terminal-Icons'
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    same 'already installed'
}
else {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -AllowClobber
    did 'installed'
}

# --- CaskaydiaCove Nerd Font -------------------------------------------------
# Not in the winget archive -- only JetBrainsMono is -- so it comes from the Nerd Fonts
# release, pinned to the version wezterm.lua was verified against. Per-user: copying
# into %LOCALAPPDATA% and registering under HKCU needs no elevation. The names on the
# right are the Win32 names DirectWrite exposes the faces under; wezterm.lua asks for
# "CaskaydiaCove Nerd Font Mono", which is the NFM four.
$fontVersion = 'v3.5.1'
$fontFaces = [ordered]@{
    'CaskaydiaCoveNerdFont-Regular.ttf'        = 'CaskaydiaCove NF Regular (TrueType)'
    'CaskaydiaCoveNerdFont-Bold.ttf'           = 'CaskaydiaCove NF Bold (TrueType)'
    'CaskaydiaCoveNerdFont-Italic.ttf'         = 'CaskaydiaCove NF Italic (TrueType)'
    'CaskaydiaCoveNerdFont-BoldItalic.ttf'     = 'CaskaydiaCove NF Bold Italic (TrueType)'
    'CaskaydiaCoveNerdFontMono-Regular.ttf'    = 'CaskaydiaCove NFM Regular (TrueType)'
    'CaskaydiaCoveNerdFontMono-Bold.ttf'       = 'CaskaydiaCove NFM Bold (TrueType)'
    'CaskaydiaCoveNerdFontMono-Italic.ttf'     = 'CaskaydiaCove NFM Italic (TrueType)'
    'CaskaydiaCoveNerdFontMono-BoldItalic.ttf' = 'CaskaydiaCove NFM Bold Italic (TrueType)'
}

info ''
info "CaskaydiaCove Nerd Font $fontVersion"
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontKey = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$missingFaces = @($fontFaces.Keys | Where-Object { -not (Test-Path -LiteralPath (Join-Path $fontDir $_)) })

if ($missingFaces.Count -eq 0) {
    same 'all eight faces already installed'
}
else {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nerd-fonts-$(Get-Random)"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        # CascadiaCode.zip is the patched Cascadia Code; the faces inside it are named
        # CaskaydiaCove, and both the proportional and the Mono cut ship in the one zip.
        $zip = Join-Path $tmp 'CascadiaCode.zip'
        $url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$fontVersion/CascadiaCode.zip"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force

        New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
        if (-not (Test-Path -LiteralPath $fontKey)) { New-Item -Path $fontKey -Force | Out-Null }

        foreach ($file in $missingFaces) {
            $src = Join-Path $tmp $file
            if (-not (Test-Path -LiteralPath $src)) {
                warn "$file is not in the $fontVersion zip -- the release may have renamed it"
                continue
            }
            $dest = Join-Path $fontDir $file
            Copy-Item -LiteralPath $src -Destination $dest -Force
            Set-ItemProperty -Path $fontKey -Name $fontFaces[$file] -Value $dest
            did $file
        }
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    warn 'a WezTerm already running will not see a font installed under it -- restart it'
}

# --- dotnet global tools -----------------------------------------------------
info ''
info 'dotnet global tools'
if ($SkipDotnetTools) {
    same 'skipped'
}
elseif (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    warn 'dotnet is not on PATH yet -- open a new shell after the SDK install and re-run'
}
else {
    $installed = (dotnet tool list --global | Select-Object -Skip 2) -replace '\s.*$'
    foreach ($tool in 'dotnet-ef', 'dotnet-stryker', 'microsoft.dotnet-httprepl') {
        info "  $tool"
        if ($installed -contains $tool) { same 'already installed'; continue }
        dotnet tool install --global $tool
        if ($LASTEXITCODE -eq 0) { did 'installed' } else { warn "dotnet exited $LASTEXITCODE" }
    }

    # The Aspire CLI is what `aspire run` is, and it is not a NuGet global tool -- it
    # has its own installer, which drops it in ~/.aspire/bin and puts that on PATH.
    info '  aspire'
    if (Get-Command aspire -ErrorAction SilentlyContinue) {
        same 'already installed'
    }
    else {
        warn 'not installed -- see https://aspire.dev (its install script, not a dotnet tool)'
    }
}

# --- WSL2 --------------------------------------------------------------------
# The zsh half of the repo has nowhere to go without this; install.sh is what actually
# populates the distribution once it exists.
info ''
info 'WSL2 / Ubuntu-24.04'
$distros = if (Get-Command wsl -ErrorAction SilentlyContinue) {
    # wsl.exe writes UTF-16, so the output arrives with NULs between the characters.
    (wsl.exe -l -q 2>$null) -replace "`0", '' -split "`r?`n" | Where-Object { $_ }
}
else { @() }

if ($distros -contains 'Ubuntu-24.04') {
    same 'already installed'
}
elseif ($InstallWsl) {
    wsl.exe --install -d Ubuntu-24.04 --no-launch
    did 'installed -- reboot, then start it once to create your user'
}
else {
    warn 'not installed. It needs an elevated shell and a reboot, so it is opt-in:'
    warn '  pwsh -NoProfile -File .\bootstrap.ps1 -InstallWsl'
}

# --- symlink readiness -------------------------------------------------------
# install.ps1 gets by with junctions, which need no privilege. What does need it is a
# real symlink: git checking one out, or anything pointing across into a Windows path.
info ''
info 'symlinks'
$devMode = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name AllowDevelopmentWithoutDevLicense -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense
if ($devMode -eq 1) {
    same 'Developer Mode is on -- unprivileged symlinks work'
}
else {
    warn 'Developer Mode is off. Junctions (what install.ps1 uses) still work; a real'
    warn 'symlink on the Windows side needs it. Settings > System > For developers.'
}

$coreSymlinks = git config --global --get core.symlinks 2>$null
if ($coreSymlinks -eq 'true') { same 'git core.symlinks = true' }
else { warn "git core.symlinks is '$coreSymlinks' -- a repo containing symlinks checks out as plain text files" }

# --- next --------------------------------------------------------------------
info ''
Write-Host 'Done. Next:' -ForegroundColor Cyan
Write-Host '  pwsh -NoProfile -File .\install.ps1        # link the configs' -ForegroundColor Cyan
Write-Host '  bash ~/.dotfiles/install.sh                # from inside Ubuntu-24.04' -ForegroundColor Cyan
Write-Host 'Then open a new WezTerm window.' -ForegroundColor Cyan
