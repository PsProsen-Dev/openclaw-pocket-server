#!/bin/bash

# Force load environment variables
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

# Result monitor — safety net that sends final result if run.py didn't.
# Normally run.py sends the final notification itself. This catches edge cases
# where run.py crashes after writing last_result.json but before sending Telegram.

RESULT_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/last_result.json"
SCREENSHOT="/data/data/com.termux/files/home/storage/shared/android_agent/last_screenshot.png"
LOG_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/monitor.log"
PID_FILE="/data/data/com.termux/files/home/storage/shared/android_agent/result.pid"

# Kill any previous result monitor instance
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if [ "$OLD_PID" != "$$" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "[$(date)] Killing old result monitor (PID: $OLD_PID)" >> "$LOG_FILE"
        kill "$OLD_PID" 2>/dev/null
        sleep 1
    fi
fi

# Register our PID
echo $$ > "$PID_FILE"
echo "[$(date)] Result monitor started (PID: $$)" >> "$LOG_FILE"

WAIT_COUNT=0
MAX_WAITS=8  # 8 * 15s = 2 minutes max wait

while true; do
    if [ -f "$RESULT_FILE" ]; then
        MTIME=$(stat -c %Y "$RESULT_FILE" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        if [ $((NOW - MTIME)) -lt 60 ]; then
            # Wait — give run.py time to send its own notification first
            sleep 8

            echo "[$(date)] Result detected (safety net)" >> "$LOG_FILE"

            # Send screenshot as document (full quality, not compressed as photo)
            if [ -f "$SCREENSHOT" ] && [ -s "$SCREENSHOT" ]; then
                CAPTION=$(python3 -c "
import json
try:
    d = json.load(open('$RESULT_FILE'))
    s = '✅' if d['success'] else '❌'
    print(f'{s} {d.get(\"summary\", \"Task finished\")}\nSteps: {d.get(\"steps\", \"?\")}')
except:
    print('Task finished')
" 2>/dev/null)
                curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
                    -F "chat_id=${CHAT_ID}" \
                    -F "document=@${SCREENSHOT}" \
                    -F "caption=${CAPTION}"
            fi

            break
        fi
    fi
    sleep 15
    WAIT_COUNT=$((WAIT_COUNT + 1))
    if [ "$WAIT_COUNT" -ge "$MAX_WAITS" ]; then
        echo "[$(date)] Result monitor timed out after 2 minutes. Exiting." >> "$LOG_FILE"
        break
    fi
done

# Cleanup
rm -f "$PID_FILE"
echo "[$(date)] Result monitor exited (PID: $$)" >> "$LOG_FILE"
