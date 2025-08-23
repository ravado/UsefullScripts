#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash zorin-setup.sh [--with-chrome] [--with-brave]
# Example:
#   bash zorin-setup.sh --with-chrome --with-brave

WITH_CHROME=0
WITH_BRAVE=0
for arg in "$@"; do
  case "$arg" in
    --with-chrome) WITH_CHROME=1 ;;
    --with-brave)  WITH_BRAVE=1 ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  case esac
done

echo "🔧 Updating system & installing basics..."
sudo apt update
sudo apt install -y curl wget gpg ca-certificates flatpak

# Enable Flathub (if not already)
if ! flatpak remotes | grep -q flathub; then
  echo "➕ Enabling Flathub…"
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "📦 Installing Telegram & Viber via Flatpak (stable and easy to update)…"
flatpak install -y flathub org.telegram.desktop
flatpak install -y flathub com.viber.Viber

echo "🖥️ Installing TeamViewer (official .deb)…"
tmpdeb="/tmp/teamviewer_amd64.deb"
wget -O "$tmpdeb" "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
sudo apt install -y "$tmpdeb" || true
# Resolve any missing deps
sudo apt -f install -y

if [ "$WITH_CHROME" -eq 1 ]; then
  echo "🌐 Installing Google Chrome (for easy import/sync)…"
  chromedeb="/tmp/google-chrome-stable_current_amd64.deb"
  wget -O "$chromedeb" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
  sudo apt install -y "$chromedeb" || true
  sudo apt -f install -y
fi

if [ "$WITH_BRAVE" -eq 1 ]; then
  echo "🦁 Installing Brave Browser (official repo)…"
  # Add Brave repo key
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  # Add repo (Ubuntu/Jammy base works for Zorin 17)
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
    sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
  sudo apt update
  sudo apt install -y brave-browser
fi

echo "✅ Done. Installed: TeamViewer, Viber, Telegram $( [ $WITH_CHROME -eq 1 ] && echo ', Chrome' ) $( [ $WITH_BRAVE -eq 1 ] && echo ', Brave' )."