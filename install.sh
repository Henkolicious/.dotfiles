#!/usr/bin/env bash
#
# Puts the configs under home/ where WSL looks for them, and installs what renders
# them. Idempotent. The counterpart of install.ps1, which does the same for Windows.
#
# Unlike Windows, Linux has an unprivileged `ln -s`, so everything here is a real
# symlink back into the repo -- including starship.toml, which the Windows side has to
# point at with an environment variable instead. Both shells therefore read one file.
#
# Anything real found in a target path is moved aside to <name>.bak-<timestamp>
# rather than deleted.
#
# Run it from inside the distribution:
#
#     bash ~/.dotfiles/install.sh          (or /mnt/c/Users/<you>/.dotfiles/install.sh)
#
# It asks for your password twice: once for apt, once for chsh.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stamp=$(date +%Y%m%d-%H%M%S)

# Where this script puts starship and nvim. A non-login shell has not read the zshrc
# that adds it, so without this the checks below would miss what a previous run
# installed and do the work again.
export PATH="$HOME/.local/bin:$PATH"

info()  { printf '%s\n' "$*"; }
same()  { printf '\033[90m  %s\033[0m\n' "$*"; }
did()   { printf '\033[32m  %s\033[0m\n' "$*"; }
warn()  { printf '\033[33m  %s\033[0m\n' "$*"; }

backup_existing() {
    local path=$1
    [[ -e $path || -L $path ]] || return 0
    mv -- "$path" "$path.bak-$stamp"
    warn "moved aside -> $path.bak-$stamp"
}

link() {
    # A symlink already pointing at the repo copy is left alone; a real file or
    # directory in the way is moved aside first.
    local target=$1 source=$2
    info "$(basename -- "$target") -> $source"

    if [[ -L $target ]]; then
        if [[ $(readlink -- "$target") == "$source" ]]; then
            same "already linked"
            return 0
        fi
        rm -- "$target"          # drops the link, not what it pointed at
    elif [[ -e $target ]]; then
        backup_existing "$target"
    fi

    mkdir -p -- "$(dirname -- "$target")"
    ln -s -- "$source" "$target"
    did "linked"
}

# --- starship ----------------------------------------------------------------
# Into ~/.local/bin rather than /usr/local/bin: it needs no root there, and it is the
# same place nvim goes. Not in the apt archive at all.
info 'starship'
if command -v starship >/dev/null 2>&1; then
    same "already installed ($(starship --version | head -1))"
else
    mkdir -p -- "$HOME/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin" >/dev/null
    did "installed -> ~/.local/bin/starship"
fi

# --- Neovim ------------------------------------------------------------------
# From the release tarball, not apt: noble ships 0.9.5, and the shared nvim config
# calls vim.uv, which only exists from 0.10 on. Same reason the config asks for
# snacks.nvim, which wants a current Neovim too.
info 'neovim'
nvim_ok=false
if command -v nvim >/dev/null 2>&1; then
    v=$(nvim --version | sed -n '1s/^NVIM v\([0-9]*\)\.\([0-9]*\).*/\1 \2/p')
    read -r major minor <<<"$v"
    (( major > 0 || minor >= 10 )) && nvim_ok=true
fi

if $nvim_ok; then
    same "already installed ($(nvim --version | sed -n 1p))"
else
    tmp=$(mktemp -d)
    trap 'rm -rf -- "$tmp"' EXIT
    for asset in nvim-linux-x86_64.tar.gz nvim-linux64.tar.gz; do
        # The asset was renamed part-way through the 0.10 series; try both names.
        curl -fsSL -o "$tmp/nvim.tar.gz" \
            "https://github.com/neovim/neovim/releases/latest/download/$asset" && break
    done
    top=$(tar tzf "$tmp/nvim.tar.gz" | sed -n '1s#/.*##p')
    tar xzf "$tmp/nvim.tar.gz" -C "$tmp"
    rm -rf -- "$HOME/.local/nvim"
    mkdir -p -- "$HOME/.local/bin"
    mv -- "$tmp/$top" "$HOME/.local/nvim"
    ln -sfn -- "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"
    did "installed -> ~/.local/nvim ($("$HOME/.local/bin/nvim" --version | sed -n 1p))"
fi

# --- Configs -----------------------------------------------------------------
# starship reads ~/.config/starship.toml by default, so no STARSHIP_CONFIG is needed on
# this side; the symlink is enough. ~3ms to read it back over the 9p mount, once per
# prompt, which does not show.
link "$HOME/.config/starship.toml" "$repo/home/.config/starship.toml"

# Linux Neovim does look in ~/.config/nvim, unlike the Windows one that needed
# %LOCALAPPDATA%. lazy-lock.json is shared with it deliberately: same plugins, same
# commits, and the plugins themselves land per-distribution under ~/.local/share/nvim.
link "$HOME/.config/nvim" "$repo/home/.config/nvim"

link "$HOME/.zshrc" "$repo/home/.config/zsh/zshrc"

# The login shell is only zsh once the apt and chsh steps at the end of this script have
# run, and those are the two that need a password. Linking the bash aliases as well means
# an unanswered prompt still leaves the alias set behind, in the shell that did start.
link "$HOME/.bash_aliases" "$repo/home/.config/bash/bash_aliases"

# --- Packages ----------------------------------------------------------------
# zsh-autosuggestions is PSReadLine's inline prediction and zsh-syntax-highlighting is
# the colouring it does while you type; eza stands in for Terminal-Icons. All three are
# in noble, so there is no third-party repository to add.
packages=(zsh zsh-autosuggestions zsh-syntax-highlighting eza)
missing=()
for p in "${packages[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q '^install ok installed$' || missing+=("$p")
done

info "packages: ${packages[*]}"
if (( ${#missing[@]} == 0 )); then
    same "all present"
else
    warn "installing ${missing[*]} (sudo)"
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"
    did "installed"
fi

# --- Login shell -------------------------------------------------------------
# WezTerm's WSL entry runs `wsl.exe --distribution ... --cd ~` with no command, which
# starts whatever this says. chsh wants the password even under sudo.
zsh_path=$(command -v zsh)
info "login shell -> $zsh_path"
current=$(getent passwd "$USER" | cut -d: -f7)
if [[ $current == "$zsh_path" ]]; then
    same "already zsh"
else
    grep -qx -- "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    chsh -s "$zsh_path"
    did "set (takes effect in new shells)"
fi

echo
printf '\033[36m%s\033[0m\n' 'Done. Open a new WSL tab in WezTerm to pick everything up.'
