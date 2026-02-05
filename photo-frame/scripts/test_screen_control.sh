#!/bin/bash
set -euo pipefail

SCREEN_SCRIPT="$HOME/picframe/scripts/screen_control.sh"

echo "🧪 Testing screen control functionality..."
echo ""

# Check if script exists
if [[ ! -f "$SCREEN_SCRIPT" ]]; then
    echo "❌ Screen control script not found at $SCREEN_SCRIPT"
    exit 1
fi

# Test 1: Screen OFF
echo "1️⃣  Testing screen OFF..."
if $SCREEN_SCRIPT off; then
    echo "✅ Screen OFF successful"
else
    echo "❌ Screen OFF failed"
    exit 1
fi

echo "   Waiting 5 seconds..."
sleep 5

# Test 2: Status while OFF
echo ""
echo "2️⃣  Testing status (should show OFF)..."
$SCREEN_SCRIPT status

sleep 2

# Test 3: Screen ON
echo ""
echo "3️⃣  Testing screen ON..."
if $SCREEN_SCRIPT on; then
    echo "✅ Screen ON successful"
else
    echo "❌ Screen ON failed"
    exit 1
fi

echo "   Waiting 3 seconds..."
sleep 3

# Test 4: Status while ON
echo ""
echo "4️⃣  Testing status (should show ON)..."
$SCREEN_SCRIPT status

# Test 5: Rapid toggle
echo ""
echo "5️⃣  Testing rapid toggle..."
for i in {1..3}; do
    echo "   Toggle $i: OFF"
    $SCREEN_SCRIPT off >/dev/null
    sleep 1
    echo "   Toggle $i: ON"
    $SCREEN_SCRIPT on >/dev/null
    sleep 1
done
echo "✅ Rapid toggle successful"

# Final status
echo ""
echo "6️⃣  Final status check..."
$SCREEN_SCRIPT status

# Check logs
echo ""
echo "7️⃣  Recent log entries:"
tail -n 10 /var/log/picframe-screen.log

echo ""
echo "✅ All tests passed!"
echo ""
echo "To schedule automatic on/off:"
echo "  - Cron:    bash ~/picframe/scripts/install_crontab.sh"
echo "  - Systemd: bash ~/picframe/scripts/install_timers.sh (recommended)"
