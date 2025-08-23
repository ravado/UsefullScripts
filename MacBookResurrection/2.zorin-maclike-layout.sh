#!/usr/bin/env bash
set -euo pipefail

echo "🧰 Installing Dash-to-Dock (GNOME dock)…"
sudo apt update
sudo apt install -y gnome-shell-extension-dash-to-dock gnome-shell-extension-manager

# Enable the extension (UUID is standard for Dash-to-Dock)
EXT_UUID="dash-to-dock@micxgx.gmail.com"
if ! gnome-extensions list | grep -q "$EXT_UUID"; then
  echo "⚠️  Dash-to-Dock not listed; log out/in once and re-run this script if enabling fails."
fi
gnome-extensions enable "$EXT_UUID" || true

echo "🎛️  Applying mac-like dock settings…"
# Position & behavior
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height false
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.35
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews'

# Look & spacing
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 40
gsettings set org.gnome.shell.extensions.dash-to-dock running-indicator-style 'DOTS'
gsettings set org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true
gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false

# Center apps (disable 'show-apps-at-top' style)
gsettings set org.gnome.shell.extensions.dash-to-dock show-apps-button true
gsettings set org.gnome.shell.extensions.dash-to-dock show-favorites true
gsettings set org.gnome.shell.extensions.dash-to-dock isolate-monitors false
gsettings set org.gnome.shell.extensions.dash-to-dock isolate-workspaces false

echo "⬆️  Keeping GNOME's top bar as your app bar (no changes needed)."
echo "✅ Done. If the dock didn’t appear, log out and back in (GNOME needs to reload extensions)."