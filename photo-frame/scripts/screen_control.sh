#!/bin/bash
set -euo pipefail

# Screen control script for Raspberry Pi Zero 2W with X11
# Usage: ./screen_control.sh [on|off|status]

DISPLAY="${DISPLAY:-:0}"
export DISPLAY

XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export XAUTHORITY

LOG_FILE="/var/log/picframe-screen.log"

# Create log file if it doesn't exist
if [[ ! -f "$LOG_FILE" ]]; then
    sudo touch "$LOG_FILE"
    sudo chown $(whoami):$(whoami) "$LOG_FILE"
fi

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_x_server() {
    if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        log_message "ERROR: X server not accessible on $DISPLAY"
        return 1
    fi
    return 0
}

screen_off() {
    log_message "Turning screen OFF"

    if ! check_x_server; then
        return 1
    fi

    # Method 1: DPMS force off (preferred for X11)
    if xset dpms force off 2>/dev/null; then
        log_message "Screen turned off via DPMS"
    else
        log_message "WARNING: xset dpms force off failed"
    fi

    # Method 2: Blank screen as backup
    xset s activate 2>/dev/null || true

    # Optional Method 3: HDMI-CEC if available
    if command -v cec-client >/dev/null 2>&1; then
        echo 'standby 0' | cec-client -s -d 1 >/dev/null 2>&1 && \
            log_message "Screen turned off via HDMI-CEC"
    fi

    # Verify screen is off (wait 2 seconds for state to settle)
    sleep 2
    local DPMS_STATE=$(xset q | grep -A 2 "DPMS is" | grep "Monitor is" | awk '{print $3}' || echo "Unknown")

    if [[ "$DPMS_STATE" == "Off" ]]; then
        log_message "✅ Screen confirmed OFF"
        return 0
    else
        log_message "⚠️  Screen state unclear (DPMS: $DPMS_STATE)"
        return 1
    fi
}

screen_on() {
    log_message "Turning screen ON"

    if ! check_x_server; then
        return 1
    fi

    # Method 1: DPMS force on
    if xset dpms force on 2>/dev/null; then
        log_message "Screen turned on via DPMS"
    else
        log_message "WARNING: xset dpms force on failed"
    fi

    # Method 2: Deactivate screensaver
    xset s reset 2>/dev/null || true

    # Method 3: Move mouse cursor (wakes up some displays)
    if command -v xdotool >/dev/null 2>&1; then
        DISPLAY=$DISPLAY xdotool mousemove 0 0 2>/dev/null || true
    fi

    # Optional Method 4: HDMI-CEC if available
    if command -v cec-client >/dev/null 2>&1; then
        echo 'on 0' | cec-client -s -d 1 >/dev/null 2>&1 && \
            log_message "Screen turned on via HDMI-CEC"
    fi

    # Verify screen is on (wait 2 seconds for state to settle)
    sleep 2
    local DPMS_STATE=$(xset q | grep -A 2 "DPMS is" | grep "Monitor is" | awk '{print $3}' || echo "Unknown")

    if [[ "$DPMS_STATE" == "On" ]]; then
        log_message "✅ Screen confirmed ON"
        return 0
    else
        log_message "⚠️  Screen state unclear (DPMS: $DPMS_STATE)"
        return 1
    fi
}

get_status() {
    if ! check_x_server; then
        echo "X server not accessible"
        return 1
    fi

    local DPMS_ENABLED=$(xset q | grep "DPMS is" | awk '{print $3}')
    local DPMS_STATE=$(xset q | grep -A 2 "DPMS is" | grep "Monitor is" | awk '{print $3}' || echo "Unknown")

    echo "DPMS Status: $DPMS_ENABLED"
    echo "Monitor State: $DPMS_STATE"
    echo ""
    echo "Screen Saver Settings:"
    xset q | grep -A 5 "Screen Saver"

    log_message "Status check - DPMS: $DPMS_ENABLED, Monitor: $DPMS_STATE"
}

# Main
case "${1:-}" in
    on)
        screen_on
        ;;
    off)
        screen_off
        ;;
    status)
        get_status
        ;;
    *)
        echo "Usage: $0 {on|off|status}"
        echo ""
        echo "Commands:"
        echo "  on      - Turn screen on"
        echo "  off     - Turn screen off"
        echo "  status  - Show current screen state"
        exit 1
        ;;
esac
