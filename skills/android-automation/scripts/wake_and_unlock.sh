#!/bin/bash
# Smart Screen Wake — check before acting, preserve current app state.
# Idempotent on an already-awake screen.

# --- Check if screen is ON ---
WAKEFULNESS=$(adb shell dumpsys power 2>/dev/null | grep "mWakefulness=" | head -1 | cut -d= -f2 | tr -d '[:space:]')

if [ "$WAKEFULNESS" != "Awake" ]; then
    echo "Screen is off ($WAKEFULNESS). Waking and unlocking..."

    # Wake the screen
    adb shell input keyevent KEYCODE_WAKEUP
    sleep 1.5

    # Swipe up to dismiss lock screen (no PIN — swipe unlock only)
    SCREEN_SIZE=$(adb shell wm size 2>/dev/null | awk '{print $3}' | tr 'x' ' ')
    SW=$(echo $SCREEN_SIZE | awk '{print $1}')
    SH=$(echo $SCREEN_SIZE | awk '{print $2}')
    SW=${SW:-1080}
    SH=${SH:-2340}

    MID_X=$((SW / 2))
    START_Y=$((SH * 8 / 10))
    END_Y=$((SH * 2 / 10))

    adb shell input swipe $MID_X $START_Y $MID_X $END_Y 500
    sleep 1.0

    echo "Screen woke and unlocked."
else
    echo "Screen is already awake. Doing nothing."
fi

echo "Ready."
