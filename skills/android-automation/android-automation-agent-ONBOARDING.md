# 🦾 Iota Onboarding: Android Automation Agent

### 🚩 To the New Agent

You are being tasked with setting up the **Iota Android Automation Agent**. This is a vision-based automation tool that uses ADB and LLM analysis to perform complex UI tasks on a connected Android device, with live Telegram notifications sent back to the user.

Complete every phase in order. Do not skip phases.

---

## 🛠️ Phase 1: Environment Initialization

Clone the repository and run the setup script. The script handles Python dependencies, ADB validation, and directory creation.

```bash
# 1. Clone the repository
git clone https://github.com/Mohd-Mursaleen/android-automation-agent.git ~/android-automation-agent

# 2. Run the turnkey setup utility
cd ~/android-automation-agent && pkg install libjpeg-turbo libpng zlib libtiff libwebp openjpeg -y && pip install -r requirements.txt
```

---

## 🔑 Phase 2: API Keys & Variables

Three variables are required: `OPENROUTER_API_KEY`, `BOT_TOKEN`, and `CHAT_ID`.

### 2a. Check current state

```bash
source ~/.bashrc
echo "OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:+SET (${#OPENROUTER_API_KEY} chars)}${OPENROUTER_API_KEY:-NOT SET}"
echo "BOT_TOKEN:          ${BOT_TOKEN:+SET}${BOT_TOKEN:-NOT SET}"
echo "CHAT_ID:            ${CHAT_ID:+SET}${CHAT_ID:-NOT SET}"
```

For each variable that shows **NOT SET**, follow the resolution steps below.

---

### 2b. Resolving a missing variable

For each missing value, follow this order:

1. **Search your own context first** — check the current conversation history, any system prompts, memory files, or workspace config files (e.g. `~/.openclaw/config.json`, `~/.openclaw/workspace/*.json`) for the value.
2. **If not found in context** — ask the user directly:
   - For `OPENROUTER_API_KEY`: _"I need your OpenRouter API key to run the Android agent. Please share it."_
   - For `BOT_TOKEN`: _"I need the Telegram bot token to send you notifications. Please share it."_
   - For `CHAT_ID`: _"I need your Telegram chat ID to send you notifications. Please share it."_
3. **Once you have the value** — set it permanently using the commands below.

---

### 2c. Set a variable permanently

Replace `VARIABLE_NAME` and `the-value` with the actual name and value, then run:

```bash
# Write to ~/.bashrc so it persists across sessions
echo 'export VARIABLE_NAME="the-value"' >> ~/.bashrc
source ~/.bashrc
```

Example for all three at once (fill in actual values):

```bash
echo 'export OPENROUTER_API_KEY="sk-or-..."' >> ~/.bashrc
echo 'export BOT_TOKEN="123456789:ABCdef..."' >> ~/.bashrc
echo 'export CHAT_ID="987654321"' >> ~/.bashrc
source ~/.bashrc
```

---

### 2d. Final verification

All three must show SET before continuing to Phase 3.

```bash
source ~/.bashrc
echo "OPENROUTER_API_KEY: ${OPENROUTER_API_KEY:+SET}${OPENROUTER_API_KEY:-MISSING}"
echo "BOT_TOKEN:          ${BOT_TOKEN:+SET}${BOT_TOKEN:-MISSING}"
echo "CHAT_ID:            ${CHAT_ID:+SET}${CHAT_ID:-MISSING}"
```

Do not proceed if any show MISSING.

---

## 📂 Phase 3: Register the Skill

Copy the skill file to your OpenClaw workspace so Iota can find and invoke it.

```bash
# Create the skill directory
mkdir -p ~/.openclaw/workspace/skills/android-automation-agent/

# Copy the latest skill definition from the repo
cp ~/android-automation-agent/SKILL.md \
   ~/.openclaw/workspace/skills/android-automation-agent/SKILL.md

echo "Skill registered at ~/.openclaw/workspace/skills/android-automation-agent/SKILL.md"
```

> **Note:** Re-run this copy command any time SKILL.md is updated in the repo.

---

## 🧠 Phase 3.5: Initialize Preferences

Create the preferences file. This stores user-specific defaults (preferred apps, products, addresses) so Iota doesn't ask the same question twice.

```bash
PREFS_FILE="${HOME}/.openclaw/preferences.json"
if [ ! -f "$PREFS_FILE" ]; then
    mkdir -p "$(dirname "$PREFS_FILE")"
    echo '{}' > "$PREFS_FILE"
    echo "Created empty preferences file at $PREFS_FILE"
else
    echo "Preferences file already exists at $PREFS_FILE"
fi
```

The preferences file will be populated automatically as you use the agent and confirm choices (e.g. preferred ride app, saved addresses). See SKILL.md Section 2 for the full schema.

---

## 🧪 Phase 4: Verification (Dry Run)

Confirm the full pipeline works end-to-end: ADB device reachable, monitors running, Telegram notification delivered.

```bash
# 1. Kill any stale monitor processes and wipe old logs
bash ~/android-automation-agent/scripts/kill_monitors.sh

# 2. Wake and unlock the Android device
bash ~/android-automation-agent/scripts/wake_and_unlock.sh

# 3. Start live result + progress monitors
exec yieldMs=500 command='bash ~/android-automation-agent/scripts/monitor_result.sh'
exec yieldMs=500 command='bash ~/android-automation-agent/scripts/monitor_progress.sh'

# 4. Run a minimal test task
cd ~/android-automation-agent && python run.py "Open Settings" --steps 10 --json
```

**Expected outcomes:**

- The Android device screen wakes up
- Settings app opens on the device
- A result JSON appears in `~/storage/shared/android_agent/last_result.json`
- A Telegram message with a screenshot arrives in your chat

**If the Telegram message doesn't arrive:**

- Confirm the values are correct: `echo "BOT_TOKEN=${BOT_TOKEN}" && echo "CHAT_ID=${CHAT_ID}"`
- Test the bot directly: `curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d "chat_id=${CHAT_ID}" -d "text=test"`
- If the curl returns `{"ok":false,...}`, the token or chat ID is wrong — go back to Phase 2 and ask the user to re-confirm the values

**If ADB device not found:**

- Confirm USB debugging is enabled on the device
- Run `adb devices` — the device should appear as `authorized`
- If it shows `unauthorized`, unlock the phone and tap "Allow" on the USB debugging prompt

---

## 📜 Summary of Principles

- **Cleanup First:** Always run `kill_monitors.sh` before a new run to ensure fresh logs and no zombie processes.
- **Wake First:** Always run `wake_and_unlock.sh` before automation. The script is smart — it only wakes/unlocks if needed and never presses Home, so the current app stays in foreground for follow-up tasks.
- **Monitors Always On:** Never run the agent without both `monitor_result.sh` and `monitor_progress.sh` running — they are the only delivery path for results and screenshots back to the user.
- **Exact Intent:** Pass the user's goal string to `run.py` without substituting words, adding brand names, or guessing app flows. See SKILL.md Section 1 (Golden Rules).
- **Decompose Complex Tasks:** Break multi-step flows into separate `run.py` calls, verifying each result before proceeding to the next. If a step fails, retry once with a rephrased goal before escalating to the user.
- **Full Autonomy:** Execute the entire task end-to-end including checkout and payment — no confirmation stops unless the user explicitly asked for one. The goal is zero user intervention after the initial request.
- **Check Preferences First:** Before asking the user a question, check `~/.openclaw/preferences.json` for a saved answer.
- **Busy Check:** Always run `scripts/check_busy.sh` before starting a new automation to prevent conflicts. Only one task can run at a time.
- **Voice Feedback:** Announce task start via `termux-tts-speak` (Step 0.5) and completion (Step 4). Keep it short and natural — summarise the goal, don't read it verbatim.
- **Smart Pre-flight:** Before every run, reason through: what is the user asking, fresh or follow-up, what info is missing, how many runs needed, what step count. See SKILL.md Section 2.5.
