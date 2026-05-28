#!/bin/bash

# Kill both progress and result monitors, clear all state files

AGENT_DIR="/data/data/com.termux/files/home/storage/shared/android_agent"
PROGRESS_PID_FILE="${AGENT_DIR}/progress.pid"
RESULT_PID_FILE="${AGENT_DIR}/result.pid"
STEP_FILE="${AGENT_DIR}/last_step.json"
RESULT_FILE="${AGENT_DIR}/last_result.json"

# Kill progress monitor
if [ -f "$PROGRESS_PID_FILE" ]; then
    PID=$(cat "$PROGRESS_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping progress monitor (PID: $PID)..."
        kill "$PID" 2>/dev/null
    fi
    rm -f "$PROGRESS_PID_FILE"
else
    echo "No progress monitor PID found."
fi

# Kill result monitor
if [ -f "$RESULT_PID_FILE" ]; then
    PID=$(cat "$RESULT_PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping result monitor (PID: $PID)..."
        kill "$PID" 2>/dev/null
    fi
    rm -f "$RESULT_PID_FILE"
else
    echo "No result monitor PID found."
fi

# Fallback: kill any remaining monitor processes by name
pkill -f "monitor_result.sh" 2>/dev/null
pkill -f "monitor_progress.sh" 2>/dev/null

# Clear state files
echo "Clearing old state files..."
rm -f "$STEP_FILE"
rm -f "$RESULT_FILE"

echo "Ready for fresh run."
