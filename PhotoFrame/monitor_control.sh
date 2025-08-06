#!/bin/bash
# Used to make photo frame more reliable when powers goes off and on at night. 
# We don't want this to make the frame working at not desired times

# Set your 'turn off' and 'turn on' times in "HH:MM" format (don't forget to sync with crontab)
TURN_OFF_TIME="23:00"
TURN_ON_TIME="07:00"

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
if [ "$CURRENT_MINUTES" -ge "$TURN_OFF_MINUTES" ] || [ "$CURRENT_MINUTES" -lt "$TURN_ON_MINUTES" ]; then
    # Command to turn off the monitor
    echo "Turning off monitor at $CURRENT_TIME"
    vcgencmd display_power 0
else
    # Command to turn on the monitor
    echo "Turning on monitor at $CURRENT_TIME"
    vcgencmd display_power 1
fi
