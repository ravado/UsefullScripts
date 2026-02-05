#!/bin/bash
set -euo pipefail

CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
SCREEN_SCRIPT="$HOME_DIR/picframe/scripts/screen_control.sh"

echo "📅 Installing systemd timers for screen control..."

# Ensure script exists
if [[ ! -f "$SCREEN_SCRIPT" ]]; then
    echo "❌ Screen control script not found at $SCREEN_SCRIPT"
    exit 1
fi

chmod +x "$SCREEN_SCRIPT"

###########################
# Screen OFF Service
###########################

sudo tee /etc/systemd/system/picframe-screen-off.service > /dev/null <<EOF
[Unit]
Description=Turn off photo frame screen
After=picframe.service

[Service]
Type=oneshot
User=$CURRENT_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME_DIR/.Xauthority"
ExecStart=$SCREEN_SCRIPT off

[Install]
WantedBy=multi-user.target
EOF

###########################
# Screen OFF Timer
###########################

sudo tee /etc/systemd/system/picframe-screen-off.timer > /dev/null <<EOF
[Unit]
Description=Turn off photo frame screen at 11 PM
Requires=picframe-screen-off.service

[Timer]
OnCalendar=23:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

###########################
# Screen ON Service
###########################

sudo tee /etc/systemd/system/picframe-screen-on.service > /dev/null <<EOF
[Unit]
Description=Turn on photo frame screen
After=picframe.service

[Service]
Type=oneshot
User=$CURRENT_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$HOME_DIR/.Xauthority"
ExecStart=$SCREEN_SCRIPT on

[Install]
WantedBy=multi-user.target
EOF

###########################
# Screen ON Timer
###########################

sudo tee /etc/systemd/system/picframe-screen-on.timer > /dev/null <<EOF
[Unit]
Description=Turn on photo frame screen at 7 AM
Requires=picframe-screen-on.service

[Timer]
OnCalendar=07:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

###########################
# Enable and Start
###########################

sudo systemctl daemon-reload
sudo systemctl enable picframe-screen-on.timer
sudo systemctl enable picframe-screen-off.timer
sudo systemctl start picframe-screen-on.timer
sudo systemctl start picframe-screen-off.timer

echo "✅ Systemd timers installed and started"
echo ""
echo "Timer status:"
systemctl list-timers picframe-screen-* --no-pager
echo ""
echo "To check logs:"
echo "  sudo journalctl -u picframe-screen-on.service"
echo "  sudo journalctl -u picframe-screen-off.service"
echo ""
echo "To modify times, edit:"
echo "  /etc/systemd/system/picframe-screen-on.timer"
echo "  /etc/systemd/system/picframe-screen-off.timer"
