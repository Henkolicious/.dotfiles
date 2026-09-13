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
- **Window chrome.** Upstream hides the tab bar on a single tab and drops the title bar
  with `window_decorations = "RESIZE"`. On Windows the close/minimise buttons live in the
  title bar rather than in a strip of their own, so the tab bar has to carry them
  (`INTEGRATED_BUTTONS|RESIZE`) and cannot be hidden.
- **Prompt.** The existing starship config is kept rather than replaced by upstream's
  minimal one; its glyphs are chosen against the Nerd Font actually installed here.
- **Aliases.** zsh aliases become PowerShell functions, since PowerShell aliases take no
  arguments. `cc` stays on plain `claude`; upstream's unattended variant is `ccd`.
- **Not ported.** The Nix system settings, Homebrew, zsh itself, and the `.pi` and agent
  configs.
