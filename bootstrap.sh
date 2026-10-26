#!/usr/bin/env bash
# Bring a fresh Ubuntu (WSL2) machine far enough to clone and install the private dotfiles.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/bootstrap.sh)"
#
# Use bash -c rather than curl | bash so prompts can read the terminal. Safe to rerun.
set -euo pipefail

DOTFILES_REPO=${DOTFILES_REPO:-Justin-Stockton/dotfiles}
DOTFILES_DIR=${DOTFILES_DIR:-$HOME/dotfiles}
BREW_PREFIX=/home/linuxbrew/.linuxbrew

say() {
  printf '\n==> %s\n' "$*"
}

ask() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$|^[Yy][Ee][Ss]$ ]]
}

is_wsl() {
  grep -qi microsoft /proc/version
}

configure_wsl() {
  is_wsl || return 0
  if [[ $(</proc/1/comm) == systemd ]] && grep -qx "default=$USER" /etc/wsl.conf 2>/dev/null; then
    return
  fi
  say "Configuring /etc/wsl.conf (systemd, default user $USER, interop)"
  [[ -f /etc/wsl.conf ]] && sudo cp /etc/wsl.conf "/etc/wsl.conf.backup.$(date +%Y%m%d%H%M%S)"
  printf '[boot]\nsystemd=true\n\n[user]\ndefault=%s\n\n[interop]\nenabled=true\nappendWindowsPath=true\n' "$USER" |
    sudo tee /etc/wsl.conf >/dev/null
  cat <<'EOF'

WSL must restart to apply /etc/wsl.conf. In PowerShell run:

  wsl --shutdown

Then reopen Ubuntu and rerun this bootstrap command.
EOF
  exit 0
}

install_prerequisites() {
  say "Installing APT prerequisites"
  sudo apt-get update
  sudo apt-get install -y build-essential ca-certificates curl file git gnupg procps unzip zsh
}

install_homebrew() {
  local installer
  if [[ ! -x $BREW_PREFIX/bin/brew ]]; then
    say "Installing Homebrew"
    installer=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"
    ask "Review the Homebrew installer before running it?" && less "$installer"
    /bin/bash "$installer"
    rm -f "$installer"
  fi
  eval "$("$BREW_PREFIX/bin/brew" shellenv)"
}

install_gh() {
  [[ -x $BREW_PREFIX/bin/gh ]] && return
  say "Installing GitHub CLI"
  brew install gh
}

authenticate_github() {
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    say "Signing in to GitHub"
    echo "If no browser opens, visit https://github.com/login/device in Windows and enter the code."
    # explorer.exe opens the Windows default browser from WSL.
    is_wsl && export BROWSER=${BROWSER:-explorer.exe}
    gh auth login --hostname github.com --git-protocol https --web
  fi
  # Skip once the dotfiles' .gitconfig provides the helper; setup-git would rewrite the linked file.
  git config --get-all credential.https://github.com.helper 2>/dev/null | grep -q 'gh auth git-credential' ||
    gh auth setup-git --hostname github.com
}

clone_dotfiles() {
  if [[ -d $DOTFILES_DIR/.git ]]; then
    say "Using existing $DOTFILES_DIR"
  elif [[ -e $DOTFILES_DIR ]]; then
    echo "$DOTFILES_DIR exists but is not a Git repository; move it aside and rerun." >&2
    exit 1
  else
    say "Cloning $DOTFILES_REPO into $DOTFILES_DIR"
    gh repo clone "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
}

[[ $EUID -ne 0 ]] || {
  echo "Run this as your normal user, not root." >&2
  exit 1
}
[[ -t 0 ]] || {
  echo "Prompts need a terminal; run with bash -c \"\$(curl -fsSL ...)\" instead of piping to bash." >&2
  exit 1
}

configure_wsl
install_prerequisites
install_homebrew
install_gh
authenticate_github
clone_dotfiles

say "Running $DOTFILES_DIR/install.sh"
cd "$DOTFILES_DIR"
exec ./install.sh
