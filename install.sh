#!/bin/sh
# vim: set filetype=bash tabstop=2 shiftwidth=2 expandtab :

# Print
# -----------------------------------------------------------------------------
print_step() {
  printf "\n\033[1;34m==> %s\033[0m\n" "$1"
}

print_success() {
  printf "\033[1;32m✔ %s\033[0m\n" "$1"
}

print_warning() {
  printf "\033[1;33m⚠ %s\033[0m\n" "$1"
}

print_error() {
  printf "\033[1;31m✖ %s\033[0m\n" "$1"
}

# Functions
# -----------------------------------------------------------------------------
update_shell() {
  local shell_path
  shell_path="$(command -v zsh)"

  print_step "Changing your shell to zsh ..."
  if ! grep "$shell_path" /etc/shells >/dev/null 2>&1; then
    print_step "Adding '$shell_path' to /etc/shells"
    sudo sh -c "echo $shell_path >> /etc/shells"
  fi
  sudo chsh -s "$shell_path" "$USER"
}

hack_unsupported_tap() {
  # in the following command we might encounter .bak files that were not removed properly
  # so we ensure the actual Formula file is the one we select
  local formula
  formula="$(find $HOMEBREW_PREFIX/Library/Taps -name "$1.*" | sort | head -1)"

  if [ -f "$formula" ]; then
    if sed -i '' '/disable! date:/d' "$formula"; then
      print_success "√ $1"
    else
      hack_unsupported_tap_failed "$1"
    fi
  else
    hack_unsupported_tap_failed "$1"
  fi
}

hack_unsupported_tap_failed() {
  print_error "WARNING: unable to correct $1 formula"
  print_error "Please use 'brew edit $1' to correct the formula"
  print_error "(remove the 'disable! date:' line)"
  exit 1
}

install_asdf_plugin() {
  local name="$1"
  local url="$2"

  if ! asdf plugin list 2>/dev/null | grep -Fq "$name"; then
    if [ -n "$url" ]; then
      print_step "Installing asdf plugin '$name' from '$url' ..."
      asdf plugin add "$name" "$url"
    else
      print_step "Installing asdf plugin '$name' from default source ..."
      asdf plugin add "$name"
    fi
  else
    print_step "Updating asdf plugin '$name' ..."
    asdf plugin update "$name"
  fi
}

install_asdf_language() {
  if [ -z "$1" ]; then
    print_error "Error: Missing required language argument." >&2
    return 1
  fi

  local language="$1"
  local version="${2:-}"

  if [ -z "$version" ]; then
    version="$(asdf latest "$language")"
  fi

  if ! asdf list "$language" | grep -Fq "$version"; then
    print_step "Installing $language $version ..."
    asdf install "$language" "$version"

    print_step "Setting default $language version to $version ..."
    asdf set -u "$language" "$version"
  else
    print_success "$language $version already installed."
  fi
}

gem_install_or_update() {
  if gem list "$1" --installed >/dev/null; then
    gem update "$@"
  else
    gem install "$@"
  fi
}

version_less_than() {
  # Usage: version_less_than "1.2.3" "1.4.0" => true if 1.2.3 < 1.4.0
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$2" ]
}

trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT

set -e

arch="$(uname -m)"

if [ "$arch" = "arm64" ]; then
  HOMEBREW_PREFIX="/opt/homebrew"
else
  HOMEBREW_PREFIX="/usr/local"
fi

case "$SHELL" in
*/zsh)
  if [ "$(command -v zsh)" != "$HOMEBREW_PREFIX/bin/zsh" ]; then
    update_shell
  fi
  ;;
*)
  update_shell
  ;;
esac

if [ "$arch" = "arm64" ]; then
  print_step "Installing Rosetta ..."
  if ! pkgutil --pkg-info=com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    softwareupdate --install-rosetta --agree-to-license
  else
    print_success "✅ Rosetta already installed."
  fi
fi

print_step "Installing Homebrew ..."
if ! command -v brew >/dev/null; then
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Determine actual brew path AFTER install
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Error: brew installation failed or unexpected install location"
    exit 1
  fi
else
  print_success "✅ Homebrew already installed."
fi

if brew list | grep -Fq brew-cask; then
  print_step "Uninstalling old Homebrew-Cask ..."
  brew uninstall --force brew-cask
fi

brew analytics off

print_step "Installing packages..."
brew bundle --file=- <<EOF
# Unix
brew "git"
brew "openssl"
brew "rcm"
brew "reattach-to-user-namespace"
brew "ripgrep"
brew "the_silver_searcher"
brew "tmux"
brew "wget"
brew "zsh"

# GitHub
brew "gh"

# Image manipulation
brew "imagemagick"

# Programming language prerequisites and package managers
brew "coreutils"
brew "libyaml" # should come after openssl
brew "readline"
brew "yarn"
brew "zlib"
brew "jq"

# Databases
brew "libpq", link: true
EOF

print_step "Installing dotfiles ..."
env RCRC="$HOME/dotfiles/rcrc" rcup

# Hack Unsupported Taps
print_step "Hacking unsupported brew Taps "
brew tap homebrew/cask --force
brew tap homebrew/core --force

hack_unsupported_tap openssl@1.1
hack_unsupported_tap mysql-client@5.7
hack_unsupported_tap wkhtmltopdf

unset -f hack_unsupported_tap
unset -f hack_unsupported_tap_failed

print_step "Installing mysql-client@5.7 ..."
HOMEBREW_NO_INSTALL_FROM_API=1 brew install mysql-client@5.7
brew link --force mysql-client@5.7

print_step "Installing wkhtmltopdf ..."
HOMEBREW_NO_INSTALL_FROM_API=1 brew install wkhtmltopdf

# Mac apps
[ ! -d "/Applications/1Password.app" ] && brew install --cask 1password
[ ! -d "/Applications/Docker.app" ] && brew install --cask docker
[ ! -d "/Applications/Google Chrome.app" ] && brew install --cask google-chrome
[ ! -d "/Applications/iTerm.app" ] && brew install --cask iterm2
[ ! -d "/Applications/Loom.app" ] && brew install --cask loom
[ ! -d "/Applications/Microsoft Teams.app" ] && brew install --cask microsoft-teams
[ ! -d "/Applications/Rectangle.app" ] && brew install --cask rectangle
[ ! -d "/Applications/Slack.app" ] && brew install --cask slack
[ ! -d "/Applications/zoom.us.app" ] && brew install --cask zoom

print_step "Installing asdf version manager ..."
if [ ! -d "$HOME/.asdf" ]; then
  brew install asdf
else
  echo "asdf already installed. Checking version ..."

  if [ "$(command -v asdf)" != "$HOMEBREW_PREFIX/bin/asdf" ]; then
    # legacy version, source it before using
    if [ -f "$HOME/.asdf/asdf.sh" ]; then
      . "$HOME/.asdf/asdf.sh"
    else
      print_error "Legacy asdf installation detected but asdf.sh not found!"
      exit 1
    fi
  fi

  current_asdf_version="$(asdf version)"
  normalized_version="$(echo "$current_asdf_version" | sed -E 's/^v//; s/-.*$//')"

  if [ -z "$current_asdf_version" ]; then
    print_warning "Unable to detect current asdf version. Skipping upgrade check."
  elif version_less_than "$normalized_version" "0.16.0"; then
    print_warning "asdf version $current_asdf_version is older than 0.16.0."
    print_step "Upgrading to new Go-based asdf version (>= 0.16.0) automatically ..."

    print_step "Commenting out legacy source line in .zshrc ..."
    if grep -q "$HOMEBREW_PREFIX/libexec/asdf.sh" "$HOME/.zshrc"; then
      sed -i.bak "s|^\(.*$HOMEBREW_PREFIX/libexec/asdf.sh.*\)|# \1|" "$HOME/.zshrc"
    fi

    print_step "Backing up old asdf directory ..."
    mv "$HOME/.asdf" "$HOME/.asdf.bak"

    print_step "Installing updated asdf version manager ..."
    brew install asdf

    print_warning "Old asdf versions are no longer supported. You’ve been upgraded automatically."
  else
    print_success "asdf version $current_asdf_version is up to date."
  fi
fi

if [ ! -f "$HOME/.asdfrc" ]; then
  echo "legacy_version_file = yes" >"$HOME/.asdfrc"
fi

print_step "Installing Ruby ..."

# Export to current shell
export DLDFLAGS="-Wl,-undefined,dynamic_lookup"
export OPENSSL_CFLAGS="-Wno-error=implicit-function-declaration"
export CFLAGS=-Wno-error="implicit-function-declaration"

install_asdf_plugin "ruby" "https://github.com/asdf-vm/asdf-ruby.git"
install_asdf_language "ruby" "2.6.7"

print_step "Optimizing bundler ..."
if [ ! -f "$HOME/bundle/config" ]; then
  mkdir -p "$HOME/bundle"
  number_of_cores=$(sysctl -n hw.ncpu)
  printf "%s\n" "---\nBUNDLE_JOBS: \"$((number_of_cores - 1))\"" > "$HOME/bundle/config"
fi

print_step "Installing Node ..."
install_asdf_plugin "nodejs" "https://github.com/asdf-vm/asdf-nodejs.git"
install_asdf_language "nodejs"

print_step "Installing ssh key ..."
SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519.pub"
PRIVATE_KEY="$SSH_DIR/id_ed25519"

if [ ! -f "$KEY_FILE" ]; then
  print_warning "No SSH key found. Let's create one."

  # Prompt for email until user enters something non-empty
  while [ -z "${EMAIL:-}" ]; do
    printf "Enter your @1000bulbs.com email to generate your SSH key: "
    read -r EMAIL
  done

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  # Generate the key quietly
  ssh-keygen -q -t ed25519 -C "$EMAIL" -f "$PRIVATE_KEY" -N ""

  # Secure private keys
  find "$SSH_DIR" -type f \( -name "id_*" ! -name "*.pub" \) -exec chmod 600 {} \;

  # Optionally make public keys readable by others
  find "$SSH_DIR" -type f -name "*.pub" -exec chmod 644 {} \;

  # Fix ownership (macOS safe)
  if command -v chown >/dev/null; then
    chown -R "$USER" "$SSH_DIR"
  fi

  print_success "✅ SSH key created successfully!"
  echo "📍 Public key path: $KEY_FILE"
  echo
  echo "🔑 Here is your public key:"
  echo "------------------------------------------------------------"
  cat "$KEY_FILE"
  echo "------------------------------------------------------------"

  # Upload key to GitHub if gh CLI is installed and not in CI
  if [ -z "$CI" ] && command -v gh >/dev/null; then
    echo
    echo "👉 Now that you've seen your key, we can upload it to GitHub for you."
    printf "Do you want to upload this SSH key to GitHub now? [y/N] "
    read -r ANSWER
    case "$ANSWER" in
      [Yy])  # Matches Y or y
        # Check if already authenticated and has required scope
        if ! gh auth status --hostname github.com --show-token 2>/dev/null | grep -q 'admin:public_key'; then
          echo "🔐 Authenticating with GitHub (requesting admin:public_key scope)..."
          gh auth login --scopes "admin:public_key" --hostname github.com
        fi

        # Add SSH key
        gh ssh-key add "$KEY_FILE" --title "$(hostname) - $(date +%Y-%m-%d)"
        print_success "✅  SSH key uploaded to GitHub."
        ;;
    esac
  fi
else
  print_success "✅ SSH key already installed."
fi

# Add SSH key to macOS keychain (if available)
if command -v ssh-add >/dev/null; then
  ssh-add --apple-use-keychain "$PRIVATE_KEY" 2>/dev/null || true
fi

if [ -f "$HOME/.laptop.local" ]; then
  print_step "Running your customizations from ~/.laptop.local ..."
  . "$HOME/.laptop.local"
fi

# macOS Defaults Configuration
# This script customizes system behavior for a smoother and faster user experience.

# ========== UI/UX TWEAKS ==========

# Hide the menu bar automatically
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain _HIHideMenuBar -bool false
defaults write NSGlobalDomain _HIHideMenuBar -bool true

# Enable Dock auto-hide
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.dock autohide -bool false
defaults write com.apple.dock autohide -bool true

# Disable Dock hide/show delay for snappier feel
# Revert: add the following line to ~/.laptop.local
#   delete these keys or reset Dock defaults
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -int 0

# Hide recent apps in Dock
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.dock show-recents -bool true
defaults write com.apple.dock show-recents -bool false

# Prevent Spaces (Desktops) from rearranging based on recent use
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.dock mru-spaces -bool true
defaults write com.apple.dock mru-spaces -bool false

# Always show scroll bars
# Options: "WhenScrolling", "Automatic" or "Always"
# Revert: add the following line to ~/.laptop.local
#   defaults write -g AppleShowScrollBars -string "Automatic"
defaults write -g AppleShowScrollBars -string "Always"

# Set Finder sidebar icon size to large
# Options: 1=Small, 2=Medium, 3=Large
# Revert: add the following line to ~/.laptop.local
#   defaults write -g NSTableViewDefaultSizeMode -int 2
defaults write -g NSTableViewDefaultSizeMode -int 3

# Always expand Save and Open panels by default
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool false
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Don’t show the "open dialog" when launching document-based apps
# Revert: add the following line to ~/.laptop.local
#   defaults write -g NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool true
defaults write -g NSShowAppCentricOpenPanelInsteadOfUntitledFile -bool false

# Show full file extensions in Finder
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain AppleShowAllExtensions -bool false
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar in Finder
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.finder ShowPathbar -bool false
defaults write com.apple.finder ShowPathbar -bool true

# Disable the warning when changing a file extension
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.finder FXEnableExtensionChangeWarning -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Set new Finder windows to open in Downloads
# Revert: add the following line to ~/.laptop.local
#   reset these keys or change path
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/Downloads"

# ========== KEYBOARD & TEXT INPUT ==========

# Set a faster key repeat rate (lower is faster)
# Revert: add the following line to ~/.laptop.local
#   defaults write -g KeyRepeat -int 6 (or higher)
defaults write -g KeyRepeat -int 2

# Set a shorter delay before key repeat starts
# Revert: add the following line to ~/.laptop.local
#   defaults write -g InitialKeyRepeat -int 25 (or higher)
defaults write -g InitialKeyRepeat -int 15

# Disable auto-correct
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool true
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable automatic capitalization
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool true
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable period substitution (double space = period)
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool true
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable smart quotes
# Revert: add the following line to ~/.laptop.local
#   defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool true
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# ========== TEXTEDIT ==========

# Set TextEdit to use plain text by default
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.TextEdit RichText -bool true
defaults write com.apple.TextEdit RichText -bool false

# ========== ACTIVITY MONITOR ==========

# Set Activity Monitor update interval to 2 seconds
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.ActivityMonitor UpdatePeriod -int 5
defaults write com.apple.ActivityMonitor UpdatePeriod -int 2

# ========== OPTIONAL EXTRAS ==========

# Disable .DS_Store files on network volumes (optional)
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Set screenshot format to PNG (optional)
# Revert: add the following line to ~/.laptop.local
#   defaults write com.apple.screencapture type -string "jpg"
defaults write com.apple.screencapture type -string "png"

if [ -f "$HOME/.laptop.local" ]; then
  print_step "Running your customizations from ~/.laptop.local ..."
  . "$HOME/.laptop.local"
fi

# Restart relevant system services
for app in "Dock" "Finder" "SystemUIServer"; do
  killall "$app" >/dev/null 2>&1 || true
done

print_success "Your laptop setup is complete! (Some changes may require a reboot to take full effect.)"
