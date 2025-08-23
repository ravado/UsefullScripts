#!/usr/bin/env bash
set -euo pipefail

D2D_UUID="dash-to-dock@micxgx.gmail.com"
SCHEMA="org.gnome.shell.extensions.dash-to-dock"

echo "🔎 Checking for Dash-to-Dock…"
if ! gnome-extensions list | grep -qx "$D2D_UUID"; then
  echo "⚠️ Dash-to-Dock not found, installing…"

  # Make sure extension manager is present
  sudo apt update
  sudo apt install -y gnome-shell-extension-manager git unzip

  # Install into user extensions directory
  mkdir -p ~/.local/share/gnome-shell/extensions
  cd /tmp
  git clone https://github.com/micheleg/dash-to-dock.git dash-to-dock-latest
  cd dash-to-dock-latest
  make
  cp -r "$D2D_UUID" ~/.local/share/gnome-shell/extensions/

  echo "✅ Dash-to-Dock installed in ~/.local/share/gnome-shell/extensions/"
fi

# Enable extension
gnome-extensions enable "$D2D_UUID" || true

echo "🎛️ Applying mac-like dock settings…"
gsettings set "$SCHEMA" dock-position 'BOTTOM'
gsettings set "$SCHEMA" extend-height false
gsettings set "$SCHEMA" intellihide true
gsettings set "$SCHEMA" click-action 'minimize-or-previews'
gsettings set "$SCHEMA" running-indicator-style 'DOTS'
gsettings set "$SCHEMA" dash-max-icon-size 40
gsettings set "$SCHEMA" transparency-mode 'FIXED' || true
gsettings set "$SCHEMA" background-opacity 0.35 || true
gsettings set "$SCHEMA" custom-theme-shrink true || true
gsettings set "$SCHEMA" show-trash false || true
gsettings set "$SCHEMA" show-mounts false || true

echo "✅ Done! Log out and back in if dock doesn’t show immediately."