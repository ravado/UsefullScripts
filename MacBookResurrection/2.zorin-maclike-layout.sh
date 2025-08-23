#!/usr/bin/env bash
set -euo pipefail

D2D_UUID="dash-to-dock@micxgx.gmail.com"
UBU_UUID="ubuntu-dock@ubuntu.com"
SCHEMA="org.gnome.shell.extensions.dash-to-dock"

need() { command -v "$1" >/dev/null 2>&1 || sudo apt update && sudo apt install -y "$1"; }

echo "🔧 Ensuring prerequisites…"
need wget
need unzip
need gnome-extensions || true   # usually ships with GNOME

echo "🔎 Checking for Dash-to-Dock…"
if ! gnome-extensions list | grep -qx "$D2D_UUID"; then
  echo "⬇️  Downloading prebuilt Dash-to-Dock…"
  TMPDIR="$(mktemp -d)"
  ZIP1="https://github.com/micheleg/dash-to-dock/releases/latest/download/dash-to-dock@micxgx.gmail.com.zip"
  ZIP2="https://extensions.gnome.org/extension-data/dash-to-dockmicxgx.gmail.com.vdash.zip"  # fallback pattern; may change upstream

  if ! wget -qO "$TMPDIR/dash-to-dock.zip" "$ZIP1"; then
    echo "   Primary download failed, trying fallback…"
    wget -qO "$TMPDIR/dash-to-dock.zip" "$ZIP2"
  fi

  echo "📦 Installing Dash-to-Dock…"
  # Install to user extensions (no root)
  gnome-extensions install --force "$TMPDIR/dash-to-dock.zip" || {
    echo "❌ Could not install Dash-to-Dock. You can install via GUI:"
    echo "   sudo apt install -y gnome-shell-extension-manager && Extension Manager → search 'Dash to Dock'"
    exit 1
  }
fi

# Disable Ubuntu Dock (conflicts with D2D) if present
if gnome-extensions list | grep -qx "$UBU_UUID"; then
  echo "🚫 Disabling Ubuntu Dock to avoid conflicts…"
  gnome-extensions disable "$UBU_UUID" || true
fi

echo "✅ Enabling Dash-to-Dock…"
gnome-extensions enable "$D2D_UUID" || true

echo "🎛️ Applying mac-like dock settings…"
gsettings set "$SCHEMA" dock-position 'BOTTOM'
gsettings set "$SCHEMA" extend-height false
gsettings set "$SCHEMA" intellihide true
gsettings set "$SCHEMA" click-action 'minimize-or-previews'
gsettings set "$SCHEMA" running-indicator-style 'DOTS'
gsettings set "$SCHEMA" dash-max-icon-size 40
# Optional niceties (ignore if unsupported)
gsettings set "$SCHEMA" transparency-mode 'FIXED' || true
gsettings set "$SCHEMA" background-opacity 0.35 || true
gsettings set "$SCHEMA" custom-theme-shrink true || true
gsettings set "$SCHEMA" show-trash false || true
gsettings set "$SCHEMA" show-mounts false || true

echo "🎉 Done! If the dock doesn’t appear or looks odd, log out and log back in."