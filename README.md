# dotfiles

Windows port of the configs in [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles),
without Nix. The real files live here; the installers point Windows and WSL at them.

Two shells are covered. PowerShell 7 is the one WezTerm starts by default; zsh is what
the Ubuntu 24.04 tab gets. They share the prompt, the aliases, the editor and its
config, so a WSL pane and a PowerShell pane in the same window behave the same way.

## Install

Three steps, in this order. The first installs the programs; the other two point them
at the configs in this repo.

```powershell
# 1. Windows, from PowerShell 7 -- the programs
pwsh -NoProfile -File .\bootstrap.ps1

# 2. Windows, from PowerShell 7 -- the links
pwsh -NoProfile -File .\install.ps1
```

```bash
# 3. From inside Ubuntu-24.04
bash /mnt/c/Users/<you>/.dotfiles/install.sh
```

On a machine with no PowerShell 7 yet, Windows PowerShell 5.1 can fetch that one
package first: `winget install --id Microsoft.PowerShell --exact`.

All three are idempotent. The two `install` scripts move anything real they find in a
target path aside to `<name>.bak-<timestamp>` instead of deleting it. `install.sh` does
everything that needs no root first, so an unanswered password prompt still leaves a
working prompt behind; it asks twice at the end, once for `apt` and once for `chsh`.

### What bootstrap.ps1 installs

| | |
| --- | --- |
| winget | pwsh, WezTerm, starship, Neovim, git, gh, ripgrep, fd, fzf, jq, lazygit, herdr, VS Code, Node, .NET 10 SDK, Docker Desktop |
| Nerd Font | CaskaydiaCove v3.5.1, eight faces, per-user under `%LOCALAPPDATA%` + `HKCU` |
| PS modules | Terminal-Icons, and PSReadLine only when what is in the box predates 2.2 |
| dotnet tools | `dotnet-ef`, `dotnet-stryker`, `httprepl` — skip with `-SkipDotnetTools` |
| WSL2 | Ubuntu-24.04, behind `-InstallWsl`, because it needs elevation and a reboot |

Each package is looked for by the command it puts on PATH before winget's own inventory
is consulted, because that inventory answers a narrower question than "is this here".
Node on the machine this was written from is registered as `OpenJS.NodeJS.22` while
carrying a 24.x, so an id lookup finds nothing and a second copy would land on the first.

The font is not in the winget archive — only JetBrainsMono is — so it comes from the
pinned Nerd Fonts release. Installing per-user needs no elevation, and the value names
written under `HKCU\...\Fonts` are the Win32 names DirectWrite exposes the faces under,
which is what `wezterm.lua` resolves `CaskaydiaCove Nerd Font Mono` through.

PSReadLine is the one module that is not installed unconditionally: PowerShell 7.6 ships
2.4.5 in the box, and a gallery copy in `Documents\PowerShell\Modules` would shadow it
with something older. Only `PredictionViewStyle ListView`, which arrived in 2.2, is
actually required.

Two things bootstrap.ps1 reports rather than fixes: whether Developer Mode is on, and
what `git config --global core.symlinks` says. Both are explained under Symlinks below.

### Not covered

Deliberately outside this repo, and each one a manual step on a new machine:

- **Git identity** — `user.name` and `user.email` in `~/.gitconfig`.
- **SSH keys** and any credential store. These never belong in a dotfiles repo.
- **The Aspire CLI** — `aspire run` needs it, and it has its own installer rather than
  being a NuGet global tool. bootstrap.ps1 warns when it is missing.
- **Agent configuration** — `~/.claude` (settings, hooks, skills), `~/.codex`,
  `~/.agents`. A real part of the environment; it simply lives elsewhere.
- **`codex` inside WSL** — see the last bullet under "The WSL side".

## What lives where

### Windows

| Repo file | Where Windows looks for it | How it is linked |
| --- | --- | --- |
| `home/.config/wezterm/wezterm.lua` | `~/.config/wezterm/` | directory junction |
| `home/.config/nvim/` | `%LOCALAPPDATA%\nvim` | directory junction |
| `home/.config/starship.toml` | wherever `STARSHIP_CONFIG` says | user environment variable |
| `home/.config/herdr/config.toml` | wherever `HERDR_CONFIG_PATH` says | user environment variable |
| `home/.config/powershell/profile.ps1` | `$PROFILE` | one-line dot-sourcing stub |

Real symlinks on Windows need Developer Mode or an elevated shell; directory
junctions need neither, which is why directories get those. The single files
cannot be junctioned, so they are pointed at instead. `%APPDATA%\herdr` holds
sockets, logs and session state next to its config, so only the config is claimed.

### WSL (Ubuntu 24.04)

| Repo file | Where WSL looks for it | How it is linked |
| --- | --- | --- |
| `home/.config/zsh/zshrc` | `~/.zshrc` | symlink |
| `home/.config/bash/bash_aliases` | `~/.bash_aliases` | symlink |
| `home/.config/starship.toml` | `~/.config/starship.toml` | symlink |
| `home/.config/nvim/` | `~/.config/nvim` | symlink |

Linux has an unprivileged `ln -s`, so every one of these is a real symlink back into
the repo across `/mnt/c` -- including `starship.toml`, which on the Windows side has to
be pointed at with an environment variable instead. Both shells read the one file.
Reading it back over the 9p mount costs about 3ms, once per prompt, which does not show.

`lazy-lock.json` lives in the shared nvim directory and is shared deliberately: the same
plugins at the same commits on both sides. The plugins themselves are built per
platform, under `~/.local/share/nvim` in WSL and `%LOCALAPPDATA%` on Windows.

herdr resolves its config path once, at server start, and writes to that file itself
(onboarding state lives there). So a server already running when `HERDR_CONFIG_PATH` was
set keeps reading `%APPDATA%\herdr\config.toml`, and displacing that file only makes
herdr write a fresh one. Restart the server to pick the variable up; to change a running
one, copy the config over the path it started with and run `herdr server reload-config`.

Existing panes keep the shell they were spawned with -- `[terminal] default_shell`
applies to new panes.

## Symlinks across the Windows/WSL boundary

One copy of each config, on NTFS, with both sides pointing at it. The direction matters:
Windows reading WSL's filesystem over `\\wsl.localhost\Ubuntu-24.04\...` is slower, and
plenty of Windows programs cannot use a UNC path as a working directory at all. So the
repo lives on the Windows drive and Linux reaches across into it, never the reverse.

**A junction is a symlink when Linux looks at it.** `/mnt/c` is mounted with
`symlinkroot=/mnt/`, so DrvFs translates NTFS reparse points into Linux symlinks with
translated targets. The junction `install.ps1` creates shows up inside WSL as:

```
lrwxrwxrwx wezterm -> /mnt/c/Users/<you>/.dotfiles/home/.config/wezterm
```

Both sides therefore see the same link structure, even though only one of them can
create it without privileges.

**Developer Mode is not needed for any of this.** Junctions never needed it. Neither, as
it turns out, does `ln -s` from inside WSL onto `/mnt/c` — the 9p server creates the link
on your behalf, verified on a machine with Developer Mode off. What does need it is
Windows-*native* symlink creation: `mklink`, `New-Item -ItemType SymbolicLink`, and git
checking out a symlink. That last one is why bootstrap.ps1 reports `core.symlinks`: with
it false, a repo containing a symlink checks out as a plain text file holding the target
path, silently. Nothing here contains one today.

**The crossing costs about 3ms a read.** Twenty reads of `starship.toml`: 77ms over 9p
against 20ms from ext4, so roughly 3.8ms against 1ms each. Once per prompt that is
invisible, which is the whole reason a config file can live on the far side. The same
mount holding a `node_modules` or a git worktree is a different proposition entirely —
that is the line not to cross.

**What is machine-bound** is only the absolute path baked into each existing symlink.
`install.sh` derives the repo root from `BASH_SOURCE`, so a fresh run adapts to whatever
path the repo was cloned to; nothing hardcodes a username on either side of the boundary.

## Deviations from upstream

- **Font.** CaskaydiaCove Nerd Font Mono at 11pt, not Hack at 15 — it is what is
  installed here, and what the Windows Terminal profile uses, so the two stay in sync.
  WezTerm needs each face named explicitly or it synthesises bold from Cascadia Mono.
- **Shell.** `default_prog` is PowerShell 7, because the profile that loads starship
  lives in `Documents\PowerShell` and WezTerm would otherwise start Windows PowerShell 5.1.
- **Translucency.** `macos_window_background_blur` does nothing off macOS; the Windows 11
  equivalent is `win32_system_backdrop = 'Acrylic'`, which only shows through while
  `window_background_opacity` is below 1.
- **Window chrome.** Same as upstream — `window_decorations = "RESIZE"` and the tab bar
  hidden on a single tab. On Windows that leaves no close/minimise buttons at all, since
  they live in the title bar rather than in a strip of their own: Alt+F4 closes,
  Alt+Space then M moves, Win+arrows snap.
- **Keys.** Added on top of upstream: Ctrl+T opens a tab and Ctrl+W closes one, the way
  the rest of Windows does it. Ctrl+T and the tab bar's + button both ask which shell to
  start — PowerShell 7 or Ubuntu 24.04 under WSL2 — while Ctrl+Shift+T spawns PowerShell
  without asking. The two entries are spelled out in `launch_menu` rather than
  discovered, so docker-desktop's WSL distribution stays out of the list. Ctrl+W is passed through to nvim, vim and helix instead,
  since a key the terminal claims never reaches the program inside it and Ctrl+W is
  vim's window prefix. The stock Ctrl+Shift+T / Ctrl+Shift+W stay bound too.
- **Prompt.** The existing starship config is kept rather than replaced by upstream's
  minimal one; its glyphs are chosen against the Nerd Font actually installed here.
- **Aliases.** zsh aliases become PowerShell functions, since PowerShell aliases take no
  arguments. `cc` stays on plain `claude`; upstream's unattended variant is `ccd`. The
  same set is kept for bash as well, so it survives a distribution whose login shell has
  not been switched to zsh yet.
- **Not ported.** The Nix system settings, Homebrew, and the `.pi` and agent configs.

## The WSL side

zsh is upstream's shell, so `home/.config/zsh/zshrc` is closer to the original than the
PowerShell profile is -- the aliases are back to being aliases. What it has to work
around is the other direction: PSReadLine does things zsh needs a package for, or cannot
do at all.

- **Inline prediction.** `PredictionSource History` becomes zsh-autosuggestions, greying
  the rest of the most recent matching command in ahead of the cursor. Ctrl+F accepts it,
  the same chord the PowerShell profile binds to `AcceptSuggestion`. Its colour is set to
  starship's `muted`, so the prompt and the suggestion agree.
- **No ListView.** `PredictionViewStyle ListView` has no counterpart. zsh has nothing
  that drops a navigable list of past commands under the prompt, so only the inline half
  of the prediction carries over.
- **Syntax highlighting.** PSReadLine colours the command line as it is typed;
  zsh-syntax-highlighting is that, and has to be sourced last because it wraps every
  widget bound before it.
- **History.** zsh saves none unless told where to. `INC_APPEND_HISTORY` rather than
  `SHARE_HISTORY`, because PSReadLine does not pull other sessions' commands into a
  running one either.
- **Tab.** `EditMode Windows` cycles through completions rather than listing them, so Tab
  is bound to `menu-complete` and Shift+Tab to `reverse-menu-complete`. Completion is
  matched case-insensitively, as PowerShell's is.
- **Icons.** Terminal-Icons has no zsh counterpart; eza draws the same Nerd Font glyphs
  out of the same font. The `ll`/`la`/`l` names are the ones stock `.bashrc` defined, so
  they survive the switch to zsh.
- **Neovim from the tarball, not apt.** noble ships 0.9.5 and the shared config calls
  `vim.uv`, which arrived in 0.10. It goes to `~/.local/nvim`, needing no root, which is
  where starship goes too.
- **`co` is inert until codex is installed in the distribution.** The Windows PATH leaks
  into WSL, so `codex` resolves to the npm shim under `/mnt/c`, which dies on
  `Missing optional dependency @openai/codex-linux-x64`. The alias is kept anyway so the
  set matches on both sides; `npm install -g @openai/codex` inside WSL makes it work.
  `claude` is already installed natively, so `cc` and `ccd` need nothing.

zsh only becomes the login shell once `install.sh` has got through its apt and `chsh`
steps, and those are the two that ask for a password -- so a run that stopped at the
prompt leaves a linked but inert `~/.zshrc` and a shell that is still bash. That is what
`home/.config/bash/bash_aliases` is for: stock `.bashrc` already sources `~/.bash_aliases`
near its end, after its own `ll`/`la`/`l`, so the alias set lands in bash without editing
a file apt owns. Only the aliases carry over -- the prompt, history, completion and
line-editing sections of the zshrc are answers to PSReadLine features, and bash adopting
starship would be its own decision rather than an alias.
