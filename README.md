# dotfiles

Windows port of the configs in [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles),
without Nix. The real files live here; `install.ps1` points Windows at them.

## Install

```powershell
pwsh -NoProfile -File .\install.ps1
```

It is idempotent, and moves anything real it finds in a target path aside to
`<name>.bak-<timestamp>` instead of deleting it.

## What lives where

| Repo file | Where Windows looks for it | How it is linked |
| --- | --- | --- |
| `home/.config/wezterm/wezterm.lua` | `~/.config/wezterm/` | directory junction |
| `home/.config/nvim/` | `%LOCALAPPDATA%\nvim` | directory junction |
| `home/.config/starship.toml` | wherever `STARSHIP_CONFIG` says | user environment variable |
| `home/.config/powershell/profile.ps1` | `$PROFILE` | one-line dot-sourcing stub |

Real symlinks on Windows need Developer Mode or an elevated shell; directory
junctions need neither, which is why directories get those. The two single files
cannot be junctioned, so they are pointed at instead.

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
  arguments. `cc` stays on plain `claude`; upstream's unattended variant is `ccd`.
- **Not ported.** The Nix system settings, Homebrew, zsh itself, and the `.pi` and agent
  configs.
