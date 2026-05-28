#!/bin/bash

# setup.sh - Turnkey setup for android-automation-agent
# This script prepares the environment for any OpenClaw instance to use this agent.

echo "=== android-automation-agent Setup ==="

# 1. Make all scripts executable
echo "Setting script permissions..."
chmod +x scripts/*.sh

# 2. Check for Telegram environment variables
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "⚠️ Warning: BOT_TOKEN or CHAT_ID not found in your environment."
    echo "To fix this, add them to your ~/.bashrc:"
    echo '  echo "export BOT_TOKEN=\"your_bot_token\"" >> ~/.bashrc'
    echo '  echo "export CHAT_ID=\"your_chat_id\"" >> ~/.bashrc'
    echo "Then run: source ~/.bashrc"
else
    echo "✅ Telegram variables found."
fi

# 3. OpenRouter / API Key reminder
if [ ! -f "providers/openrouter.py" ]; then
    echo "ℹ️ Make sure to configure your provider in providers/ folder."
fi
echo "Tip: Set your OPENROUTER_API_KEY as an environment variable just like BOT_TOKEN."

# 4. Install dependencies
echo "Installing Python dependencies..."
pip install -r requirements.txt | grep -v "already satisfied"

# 5. Instructions for OpenClaw integration
INSTALL_DIR=$(pwd)
echo ""
echo "=== Setup Complete ==="
echo "To integrate with OpenClaw, copy the SKILL.md to your workspace:"
echo "cp ${INSTALL_DIR}/SKILL.md ~/.openclaw/workspace/skills/android-automation-agent/SKILL.md"
echo ""
echo "Then, tell your OpenClaw agent to REFRESH skills."
