# AGENTS.md

Instructions for an agent asked to set this environment up on a fresh Windows machine.
Read `README.md` for why any of it is shaped the way it is; this file is the procedure.

## What this reproduces

A Windows 11 workstation running WezTerm over two shells — PowerShell 7 and zsh in
Ubuntu-24.04 under WSL2 — sharing one starship prompt, one alias set, one Neovim config
and one Nerd Font, plus the toolchain for .NET and Node work. The configs live in
`home/` and nowhere else; the installers point the machine at them rather than copying.

## Procedure

Run each step to completion and read its output before starting the next. Every script
is idempotent, so a re-run after a failure is safe and costs only the checks.

**1. Clone.** Anywhere on the Windows drive. `~/.dotfiles` is the conventional spot and
the one the docs use. Do not clone it inside WSL's own filesystem: the Windows side has
to be able to reach the files, and this direction is the fast one.

**2. `pwsh -NoProfile -File .\bootstrap.ps1`** — installs the programs. Needs PowerShell
7; if the machine has none, `winget install --id Microsoft.PowerShell --exact` from
Windows PowerShell 5.1 first. Expect several UAC prompts, since winget elevates itself
for machine-scope packages.

- Add `-InstallWsl` if `wsl -l -q` does not list `Ubuntu-24.04`. It needs an elevated
  shell and a **reboot**, after which the distribution must be started once by hand to
  create the Linux user before step 4 can run.
- **Open a new shell afterwards.** The installers put things on PATH that the running
  shell will not see, `dotnet` above all. If bootstrap.ps1 warned that dotnet was
  missing, re-run it in the new shell to pick up the global tools.

**3. `pwsh -NoProfile -File .\install.ps1`** — creates the junctions, sets
`STARSHIP_CONFIG` and `HERDR_CONFIG_PATH`, and writes the `$PROFILE` stub. Anything real
it finds in a target path is moved to `<name>.bak-<timestamp>`, never deleted.

**4. `bash /mnt/c/Users/<you>/.dotfiles/install.sh`** — from inside Ubuntu-24.04.
Installs starship and Neovim under `~/.local`, symlinks the configs back across
`/mnt/c`, then asks for a password twice: once for `apt`, once for `chsh`. Everything
that needs no root happens first, so an unanswered prompt still leaves a working shell.

**5. Restart WezTerm.** A running instance will not see a font installed underneath it,
and existing panes keep the shell they were spawned with.

## Verifying it worked

- A new WezTerm window opens PowerShell 7 with the starship bar, and the Nerd Font
  glyphs in it render as glyphs rather than as boxes. Boxes mean the font step failed.
- Ctrl+T offers PowerShell and Ubuntu 24.04; the WSL tab shows the same prompt.
- `nvim` starts, lazy.nvim bootstraps itself on first launch, and `:Lazy` reports the
  plugins at the commits in `lazy-lock.json`.
- In WSL: `ls -la ~/.zshrc` points into `/mnt/c/.../.dotfiles/home/.config/zsh/zshrc`.
- `dotnet --list-sdks` shows a 10.x, and `dotnet tool list -g` lists `dotnet-ef`.

## What is still manual afterwards

None of these are in the repo, and the setup is not finished until someone has decided
about each. Ask rather than assume.

- **Git identity.** `git config --global user.name` / `user.email`.
- **SSH keys**, GitHub auth (`gh auth login`), any cloud credentials.
- **The Aspire CLI.** Not a NuGet global tool; it has its own installer. bootstrap.ps1
  reports it as missing but will not install it.
- **Agent configuration** — `~/.claude`, `~/.codex`, `~/.agents`. Part of the working
  environment, kept out of this repo on purpose.
- **`codex` in WSL.** The Windows PATH leaks into the distribution, so `codex` resolves
  to the npm shim under `/mnt/c` and fails on a missing Linux binary.
  `npm install -g @openai/codex` inside WSL fixes it. `claude` is installed natively and
  needs nothing.

## Rules for changing this repo

- **The config file in `home/` is the only copy.** If a program has written its own
  version somewhere, the fix is to point the program back here, not to sync two files.
- **Say why, in the file.** Every non-obvious line here carries a comment explaining
  what it is working around. Keep that up; it is what makes the repo portable at all.
- **Stay idempotent, and never delete.** Displace to `<name>.bak-<timestamp>` instead.
- **No secrets.** The repo is public. Nothing that authenticates anything goes in it.
