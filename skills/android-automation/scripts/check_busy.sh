#!/bin/bash
# Check if an automation task is currently running.
# Exit 0 = free (no task running)
# Exit 1 = busy (task running, details printed to stdout)

LOCK_FILE="${HOME}/storage/shared/android_agent/agent.lock"

# No lock file = free
if [ ! -f "$LOCK_FILE" ]; then
    echo "FREE"
    exit 0
fi

# Lock file exists — check if the PID is still alive
PID=$(python3 -c "
import json
try:
    d = json.load(open('$LOCK_FILE'))
    print(d.get('pid', ''))
except:
    print('')
" 2>/dev/null)

if [ -z "$PID" ]; then
    # Corrupt lock file — clean up
    rm -f "$LOCK_FILE"
    echo "FREE"
    exit 0
fi

# Check if process is actually running
if kill -0 "$PID" 2>/dev/null; then
    # Process alive — read details
    DETAILS=$(python3 -c "
import json
try:
    d = json.load(open('$LOCK_FILE'))
    goal = d.get('goal', 'unknown task')
    started = d.get('started_at', 'unknown time')
    print(f'{goal} (started: {started})')
except:
    print('unknown task')
" 2>/dev/null)
    echo "BUSY: $DETAILS"
    exit 1
else
    # PID is dead — stale lock, clean up
    rm -f "$LOCK_FILE"
    echo "FREE"
    exit 0
fi
