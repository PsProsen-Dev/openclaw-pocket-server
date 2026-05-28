#!/bin/bash

# Force load environment variables
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Live progress monitor — sends screenshot + action log every 60s
# Auto-exits if no step updates for 2 minutes (automation dead/cancelled)

STEP_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/last_step.json"
RESULT_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/last_result.json"
PID_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/progress.pid"
LOG_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/monitor.log"
PROGRESS_SCREENSHOT="/data/data/com.termux/files/home/storage/shared/android_agent/progress_screen.png"

# Kill any previous progress monitor instance
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[$(date)] Killing old progress monitor (PID: $OLD_PID)" >> "$LOG_FILE"
        kill "$OLD_PID" 2>/dev/null
        sleep 1
    fi
fi

# Register our PID
echo $$ > "$PID_FILE"
echo "[$(date)] Progress monitor started (PID: $$)" >> "$LOG_FILE"

LAST_ACTIVITY=$(date +%s)

while true; do
    sleep 60

    # Exit if result file is fresh (task ended normally)
    if [ -f "$RESULT_FILE" ]; then
        MTIME=$(stat -c %Y "$RESULT_FILE" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        if [ $((NOW - MTIME)) -lt 90 ]; then
            echo "[$(date)] Result file updated, stopping progress monitor." >> "$LOG_FILE"
            break
        fi
    fi

    # Exit if no step updates for 2 minutes (automation died/cancelled)
    NOW=$(date +%s)
    if [ -f "$STEP_FILE" ]; then
        STEP_MTIME=$(stat -c %Y "$STEP_FILE" 2>/dev/null || echo 0)
        if [ $((NOW - STEP_MTIME)) -gt 120 ]; then
            echo "[$(date)] No step updates for 2 minutes — automation appears dead. Exiting." >> "$LOG_FILE"
            break
        fi
        LAST_ACTIVITY=$NOW
    else
        if [ $((NOW - LAST_ACTIVITY)) -gt 120 ]; then
            echo "[$(date)] No activity for 2 minutes — exiting." >> "$LOG_FILE"
            break
        fi
    fi

    # Only send update if step file was updated recently (within last 90s)
    if [ -f "$STEP_FILE" ]; then
        STEP_MTIME=$(stat -c %Y "$STEP_FILE" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        if [ $((NOW - STEP_MTIME)) -lt 90 ]; then
            CAPTION=$(python3 -c "
import json
try:
    d = json.load(open('$STEP_FILE'))
    step = d.get('step', '?')
    action = d.get('last_action', 'unknown')
    elapsed = d.get('elapsed_seconds', 0)
    goal = d.get('goal', '')
    if len(action) > 200:
        action = action[:200] + '...'
    print(f'⏳ Step {step} | {elapsed}s elapsed\n\nLast action: {action}\n\nGoal: {goal}')
except:
    print('⏳ Progress update')
" 2>/dev/null)

            # Take fresh screenshot
            adb exec-out screencap -p > "$PROGRESS_SCREENSHOT" 2>/dev/null

            if [ -f "$PROGRESS_SCREENSHOT" ] && [ -s "$PROGRESS_SCREENSHOT" ]; then
                echo "[$(date)] Sending progress screenshot" >> "$LOG_FILE"
                curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" \
                    -F "chat_id=${CHAT_ID}" \
                    -F "photo=@${PROGRESS_SCREENSHOT}" \
                    -F "caption=${CAPTION}"
            else
                echo "[$(date)] Screenshot failed, sending text only" >> "$LOG_FILE"
                curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                    -d "chat_id=${CHAT_ID}" \
                    --data-urlencode "text=${CAPTION}"
            fi

            rm -f "$PROGRESS_SCREENSHOT"
        fi
    fi
done

# Cleanup
rm -f "$PID_FILE"
rm -f "$PROGRESS_SCREENSHOT"
echo "[$(date)] Progress monitor exited (PID: $$)" >> "$LOG_FILE"
