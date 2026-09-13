# PowerShell 7 profile. The real $PROFILE is a stub that dot-sources this file;
# see ~/.dotfiles/install.ps1.

Import-Module PSReadLine
Import-Module -Name Terminal-Icons

Invoke-Expression (&starship init powershell)

$env:EDITOR = 'nvim'

# --- Aliases ported from the zsh set in kunchenguid/dotfiles ------------------
# PowerShell has no alias-with-arguments, so these are functions. ".." is a legal
# function name; bare ".." is otherwise a parse error, unlike in zsh.
function .. { Set-Location .. }
function add { git add . }
function push { git push @args }
function pull { git pull @args }
function m { git switch main }

# Upstream runs both agents unattended. cc stays on plain `claude` -- the permission
# prompts are the only thing between an agent and this machine -- and the unattended
# variant gets its own name, so skipping them stays a deliberate keystroke.
Set-Alias cc claude
function ccd { claude --dangerously-skip-permissions @args }
function co { codex --full-auto @args }

# --- PSReadLine --------------------------------------------------------------
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
# Upstream binds ^f to zsh's autosuggest-accept; this is the same gesture.
Set-PSReadLineKeyHandler -Chord Ctrl+f -Function AcceptSuggestion

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows
