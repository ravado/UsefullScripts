#!/bin/bash
# Used to make photo frame more reliable when powers goes off and on at night. 
# We don't want this to make the frame working at not desired times

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <home|batanovs|cherednychoks>"
  exit 1
fi

frame=$(echo "$1" | tr '[:upper:]' '[:lower:]')

# Set your 'turn off' and 'turn on' times in "HH:MM" format (don't forget to sync with crontab)
if [[ $frame == "home" ]]; then
    TURN_ON_TIME="07:00"
    TURN_OFF_TIME="21:00"
elif [[ $frame == "batanovs" ]]; then
    TURN_ON_TIME="07:00"
    TURN_OFF_TIME="23:00"
elif [[ $frame == "cherednychoks" ]]; then
    TURN_ON_TIME="05:00"
    TURN_OFF_TIME="23:00"
else
    echo "Unknown photoframe '$frame'"
    exit 1
fi


# Convert times to minutes since midnight for easy comparison
convert_to_minutes() {
    IFS=: read -r hour minute <<< "$1"
    echo $((10#$hour * 60 + 10#$minute))
}

TURN_OFF_MINUTES=$(convert_to_minutes "$TURN_OFF_TIME")
TURN_ON_MINUTES=$(convert_to_minutes "$TURN_ON_TIME")
CURRENT_TIME=$(date +"%H:%M")
CURRENT_MINUTES=$(convert_to_minutes "$CURRENT_TIME")

# Check if current time is outside the active period
# Set X env vars in case xset is used
export DISPLAY=:0
if [ "$CURRENT_MINUTES" -ge "$TURN_OFF_MINUTES" ] || [ "$CURRENT_MINUTES" -lt "$TURN_ON_MINUTES" ]; then
    echo "🔌 Turning OFF monitor at $CURRENT_TIME"
    vcgencmd display_power 0 2>/dev/null
    xset dpms force off 2>/dev/null
else
    echo "💡 Turning ON monitor at $CURRENT_TIME"
    vcgencmd display_power 1 2>/dev/null
    xset dpms force on 2>/dev/null
fi