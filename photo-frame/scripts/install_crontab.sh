#!/bin/bash
set -euo pipefail

CURRENT_USER=$(whoami)
HOME_DIR=$(eval echo ~$CURRENT_USER)
SCREEN_SCRIPT="$HOME_DIR/picframe/scripts/screen_control.sh"

echo "📅 Installing screen control crontab..."

# Ensure script exists
if [[ ! -f "$SCREEN_SCRIPT" ]]; then
    echo "❌ Screen control script not found at $SCREEN_SCRIPT"
    exit 1
fi

# Ensure script is executable
chmod +x "$SCREEN_SCRIPT"

# Create log file with proper permissions
sudo touch /var/log/picframe-screen.log
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/picframe-screen.log

sudo touch /var/log/picframe-cron.log
sudo chown $CURRENT_USER:$CURRENT_USER /var/log/picframe-cron.log

# Backup existing crontab
crontab -l > /tmp/crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || true

# Create new crontab with environment variables
cat > /tmp/picframe_cron << EOF
# Environment variables for X11 access
DISPLAY=:0
XAUTHORITY=$HOME_DIR/.Xauthority
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Screen off at 23:00 (11 PM)
0 23 * * * $SCREEN_SCRIPT off >> /var/log/picframe-cron.log 2>&1

# Screen on at 07:00 (7 AM)
0 7 * * * $SCREEN_SCRIPT on >> /var/log/picframe-cron.log 2>&1

# Optional: Status check at noon
0 12 * * * $SCREEN_SCRIPT status >> /var/log/picframe-cron.log 2>&1
EOF

# Install crontab
crontab /tmp/picframe_cron
rm /tmp/picframe_cron

echo "✅ Crontab installed successfully"
echo ""
echo "Current schedule:"
crontab -l
echo ""
echo "Logs:"
echo "  - Screen control: /var/log/picframe-screen.log"
echo "  - Cron execution: /var/log/picframe-cron.log"
