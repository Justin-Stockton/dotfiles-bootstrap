# dotfiles-bootstrap

Public first-run scripts for a Windows 11 + Ubuntu 24.04 WSL2 workstation. They
need no GitHub sign-in to download. They get the machine as far as
authenticating `gh`, then clone the private
[`Justin-Stockton/dotfiles`](https://github.com/Justin-Stockton/dotfiles)
repository and hand off to its `install.sh`.

Nothing here is secret: no keys, tokens, hostnames, or private configuration.
Both scripts are safe to rerun.

## 1. Windows

In an Administrator PowerShell:

```powershell
irm https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/bootstrap.ps1 | iex
```

[`bootstrap.ps1`](bootstrap.ps1):

- installs 1Password, Tailscale, WezTerm, JetBrainsMono Nerd Font, and npiperelay
  (relays the 1Password SSH agent into WSL) with Winget
- upgrades Windows Terminal and merges [`windows-terminal.json`](windows-terminal.json)
  into its settings: Catppuccin Mocha and Tokyo Night colors, the Catppuccin tab theme,
  JetBrainsMono Nerd Font, keybindings, and Ubuntu 24.04 as the default profile. The
  machine's own profile list is kept, and the old settings are backed up.
- disables the Windows OpenSSH Authentication Agent so 1Password owns the agent pipe
- writes `%USERPROFILE%\.wslconfig` (mirrored networking, DNS tunneling, auto proxy),
  backing up any different existing file
- installs WSL2 and Ubuntu 24.04, updates WSL, and sets version 2 as the default

Reboot if WSL asks for it, then sign in to 1Password and Tailscale.

## 2. Ubuntu

Open Ubuntu 24.04, create your Linux user, then run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Justin-Stockton/dotfiles-bootstrap/main/bootstrap.sh)"
```

Use `bash -c`, not `curl | bash`; the prompts need the terminal.

[`bootstrap.sh`](bootstrap.sh):

1. Writes `/etc/wsl.conf` (systemd, default user, interop) if systemd is not
   running or the default user is unset, backs up the old file, and exits so you can
   run `wsl --shutdown` in PowerShell and rerun the same command.
2. Installs the APT prerequisites for Git and Homebrew: `build-essential`,
   `ca-certificates`, `curl`, `file`, `git`, `gnupg`, `procps`, `unzip`, and `zsh`.
3. Installs Homebrew with its official installer, with an option to review it first.
4. Installs `gh` from Homebrew. Ubuntu's packaged `gh` is too old for the
   device-login flow.
5. Runs `gh auth login` over HTTPS and `gh auth setup-git`, so Git, Go modules,
   and later private clones use the same login.
6. Clones the private dotfiles to `~/dotfiles` and runs `./install.sh`.

Set `DOTFILES_REPO` or `DOTFILES_DIR` to override the repository or the clone path.
