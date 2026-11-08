# bootstrap

Bootstrap script to set up a new macOS or Arch Linux machine with my dotfiles.

## What it does

The `dotfiles` script detects your operating system, installs the necessary
dependencies, authenticates Git operations with GitHub CLI, verifies access to
the private dotfiles repository, and applies the dotfiles with
[chezmoi](https://www.chezmoi.io/).

### macOS

1. Installs [Homebrew](https://brew.sh/) (if not already installed)
2. Installs `chezmoi`, `zsh`, `age`, and `gh` (GitHub CLI) via Homebrew
3. Prompts for GitHub browser authentication if no valid session exists
4. Configures Git to use GitHub CLI credentials and verifies access to
   `fernandoaleman/dotfiles`
5. Runs chezmoi from `~/code/dotfiles`, matching the source directory expected
   by the dotfiles configuration

### Arch Linux

1. Installs `chezmoi` to `~/.local/bin` (if not already installed)
2. Installs `age`, `zsh`, and `github-cli` via pacman
3. Prompts for GitHub browser authentication if no valid session exists
4. Configures Git to use GitHub CLI credentials and verifies access to
   `fernandoaleman/dotfiles`
5. Runs chezmoi from `~/code/dotfiles`, matching the source directory expected
   by the dotfiles configuration

GitHub CLI stores credentials in the operating system's secure credential
store when one is available. Without a supported credential store, it may fall
back to storing credentials in its configuration file.

## Usage

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/fernandoaleman/bootstrap/master/dotfiles)
```

## Requirements

- macOS or Arch Linux
- `curl` (pre-installed on most systems)
- `sudo` access (for pacman on Arch Linux)
- A GitHub account with access to the private `fernandoaleman/dotfiles`
  repository
