# bootstrap

Bootstrap script to set up a new macOS or Arch Linux machine with my dotfiles.

## What it does

The `dotfiles` script detects your operating system and installs the necessary dependencies, then applies dotfiles using [chezmoi](https://www.chezmoi.io/).

### macOS

1. Installs [Homebrew](https://brew.sh/) (if not already installed)
2. Installs `chezmoi`, `zsh`, and `age` via Homebrew
3. Runs `chezmoi init --apply` to clone and apply dotfiles

### Arch Linux

1. Installs `chezmoi` to `~/.local/bin` (if not already installed)
2. Installs `age` and `zsh` via pacman
3. Runs `chezmoi init --apply` to clone and apply dotfiles

## Usage

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/fernandoaleman/bootstrap/master/dotfiles)
```

## Requirements

- macOS or Arch Linux
- `curl` (pre-installed on most systems)
- `sudo` access (for pacman on Arch Linux)
