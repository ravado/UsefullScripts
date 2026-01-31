#!/usr/bin/env bash
set -euo pipefail

# Flags
WITH_CHROME=0
WITH_BRAVE=0
for arg in "$@"; do
  case "$arg" in
    --with-chrome) WITH_CHROME=1 ;;
    --with-brave)  WITH_BRAVE=1 ;;
    *) echo "Unknown flag: $arg"; exit 1 ;;
  esac
done

echo "🔧 Updating system & installing basics…"
sudo apt update
sudo apt install -y curl wget gpg ca-certificates flatpak

# Enable Flathub (system-wide) if missing
if ! flatpak remotes | grep -q flathub; then
  echo "➕ Enabling Flathub…"
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "📦 Installing apps (Flatpak)…"
# Telegram
flatpak install -y flathub org.telegram.desktop
# Viber
flatpak install -y flathub com.viber.Viber
# Signal
flatpak install -y flathub org.signal.Signal

echo "🖥️ Installing TeamViewer (.deb)…"
tmpdeb="$(mktemp /tmp/teamviewer_XXXX.deb)"
wget -qO "$tmpdeb" "https://download.teamviewer.com/download/linux/teamviewer_amd64.deb"
# Try install; if deps missing, fix and retry
sudo apt install -y "$tmpdeb" || { sudo apt -f install -y; sudo apt install -y "$tmpdeb"; }

if [ "$WITH_CHROME" -eq 1 ]; then
  echo "🌐 Installing Google Chrome…"
  chromedeb="$(mktemp /tmp/chrome_XXXX.deb)"
  wget -qO "$chromedeb" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
  sudo apt install -y "$chromedeb" || { sudo apt -f install -y; sudo apt install -y "$chromedeb"; }
fi

if [ "$WITH_BRAVE" -eq 1 ]; then
  echo "🦁 Installing Brave Browser…"
  sudo install -d -m 0755 /usr/share/keyrings
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | \
    sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
  sudo apt update
  sudo apt install -y brave-browser
fi

echo "✅ Done. Installed TeamViewer, Viber, Telegram, Signal$( [ $WITH_CHROME -eq 1 ] && echo ', Chrome' )$( [ $WITH_BRAVE -eq 1 ] && echo ', Brave' )."