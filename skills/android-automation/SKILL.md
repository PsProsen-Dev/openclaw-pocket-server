---
name: android-automation-agent
description: Use android-automation-agent to run precise Android UI automation tasks via ADB and LLM vision on the connected Android device. Trigger this skill for ANY request involving controlling, tapping, opening, searching, ordering, booking, or interacting with apps on the user's Android phone. Also trigger for "what's on my screen" or "show me the phone".
metadata:
  { "clawdbot": { "emoji": "📱", "requires": { "bins": ["adb", "python3"] } } }
---

# android-automation-agent

Automates real Android UI via ADB + LLM vision. One goal string in, one JSON result out.

---

## SECTION 1 — GOLDEN RULES (never violate these)

### Rule 1: Never rewrite the user's words

You are a DISPATCHER, not an interpreter. Your job is to pass the user's
intent to the android agent as faithfully as possible.

- User says "bike ride" → goal says "bike ride". NOT "Uber Moto".
- User says "order food" → goal says "order food". NOT "order butter chicken on Swiggy".
- User says "Instamart" → goal says "Open Instamart". NOT "Open Swiggy, navigate to Instamart".
- User says "milk" → goal says "milk". NOT "Amul Toned Milk 500ml".

The android agent reads the screen visually. It will find the right element.
You MUST trust it. Do NOT "help" by guessing UI labels, product names, or app flows.

### Rule 2: Never assume — ask first

If the user's request is missing critical information, ASK before running.

**Always ask for:**
- Which app to use (if not specified)
- Specific item details (brand, size, variant — if ordering/searching)
- Destination/address (if booking rides or deliveries)
- Any choice that has multiple options (payment method, timing, etc.)

**Never ask for:**
- Mechanical UI steps (how to navigate within an app — the agent handles this)
- Things already answered in this conversation or in preferences.json

**Example:**
```
User: "Book me a ride to college"
You: "Which app should I use — Uber, Ola, or Rapido?"
User: "Uber"
You: "Got it. What's your college address? Or should I just type 'college' in the destination?"
User: "Just type SIRMVIT Bengaluru"
→ Goal: "Open Uber, set destination to SIRMVIT Bengaluru, wait for ride options to load"
```

### Rule 3: Check preferences before asking

Before asking the user, check `~/.openclaw/preferences.json` for saved answers.
If a preference exists, use it silently. If not, ask, then offer to save it.

### Rule 4: Break complex tasks into separate runs

The android agent handles simple-to-medium tasks best. For complex multi-step workflows,
decompose into sequential atomic runs for higher success rates.

Run each step separately. Check the result JSON between each run.
If a step fails, try a different approach or re-run it.
If a step succeeds, proceed to the next step immediately — do not stop to ask the user.
The goal is full task completion with zero user intervention after the initial request.

---

## SECTION 2 — Preferences System

### File: `~/.openclaw/preferences.json`

If this file doesn't exist, create it with `{}` as content on first use.

Structure:
```json
{
  "apps": {
    "groceries": "Blinkit",
    "rides": "Uber",
    "food_delivery": "Swiggy"
  },
  "products": {
    "milk": {
      "name": "Nandini Toned Milk",
      "quantity": "500ml",
      "app": "Blinkit"
    }
  },
  "addresses": {
    "home": "123 Example Street, Bengaluru",
    "college": "SIRMVIT, Bengaluru"
  },
  "defaults": {
    "payment_method": "Google Pay"
  }
}
```

### How to use preferences

1. When the user asks to "buy milk" → check `preferences.products.milk`
   - Found → use it: "Open Blinkit, search for Nandini Toned Milk 500ml, add to cart"
   - Not found → ask the user, then offer: "Want me to remember this for next time?"

2. When the user says "book a ride" → check `preferences.apps.rides`
   - Found → use that app without asking
   - Not found → ask which app

3. When the user says "to college" → check `preferences.addresses.college`
   - Found → use the saved address string
   - Not found → ask, then offer to save

### Saving preferences

After learning a new preference from the user, write it to the JSON file:
```bash
python3 -c "
import json, os
path = os.path.expanduser('~/.openclaw/preferences.json')
try:
    prefs = json.load(open(path))
except:
    prefs = {}
prefs.setdefault('products', {})['milk'] = {'name': 'Nandini Toned Milk', 'quantity': '500ml', 'app': 'Blinkit'}
json.dump(prefs, open(path, 'w'), indent=2)
"
```
Adapt the above pattern for whatever preference you're saving.

---

## SECTION 2.5 — Pre-flight Checklist

Before constructing the goal string or starting any run, reason through:

### 1. What is the user actually asking for?

Read the request literally. Do not embellish. Do not substitute brand names.
If it's ambiguous — not missing info, just unclear intent — pick the most natural interpretation and proceed.

### 2. Is this a fresh task or a follow-up?

Check `~/storage/shared/android_agent/last_result.json`:
- If modified < 10 minutes ago AND `success: true` AND user's words imply continuation → **follow-up**
- Otherwise → **fresh task**

For follow-ups: read `last_result.json` and `summary` field. Build the goal starting with what's already on screen. See Section 4 for full detection rules and goal construction.

### 3. How many runs will this take?

- 1 screen: 1 run
- 2–3 screens: 2 runs
- Full purchase flow (search → product → cart → checkout → pay): 3–5 runs

Plan the sequence before starting Run #1. Do not improvise mid-task.

### 4. What step count is right?

See Section 5 guidelines. When in doubt, use more steps — the agent exits early on success.

### Only after answering all four — start the run pattern in Section 3.

---

## SECTION 3 — Run Pattern

### Step 0 — Check if the agent is busy

```bash
bash ~/android-automation-agent/scripts/check_busy.sh
```

- `FREE` → proceed to Step 1.
- `BUSY: ...` → tell the user what's running and ask them to wait or cancel.

### Cancelling a running task

If the user says "cancel", "stop", or "kill the current task":

```bash
LOCK_FILE="$HOME/storage/shared/android_agent/agent.lock"
if [ -f "$LOCK_FILE" ]; then
    PID=$(python3 -c "import json; print(json.load(open('$LOCK_FILE')).get('pid',''))" 2>/dev/null)
    if [ -n "$PID" ]; then kill "$PID" 2>/dev/null; sleep 2; fi
    rm -f "$LOCK_FILE"
fi
```

Then tell the user: "Cancelled. Ready for your next task."

### Step 1 — Start the automation (non-blocking)

```
exec { "command": "cd ~/android-automation-agent && python run.py '<GOAL>' --steps <N> --json", "yieldMs": 5000 }
```

Two outcomes:
- **Returns JSON** (command finished in <5s) → go to Step 2A. Rare.
- **Returns session ID** (normal case) → go to Step 2B. The automation is now running in background.

### Step 2A — JSON returned inline

Parse it and reply:
- `success: true` → tell the user what was accomplished using the `summary` field.
- `success: false` → tell the user what failed; apply Section 7.

### Step 2B — Session ID returned (normal case)

When exec returns `Command still running (session XXXX, pid YYYY)...`, the automation IS running. Your job is done for now.

Reply to the user with exactly this (fill in the session name):
> "Automation started (session XXXX). Watch Telegram — you'll get a screenshot every 2 steps and a final result when it's done. Come back when you're ready to continue."

Then **stop calling tools.** Do not call exec again. Do not verify the session. Do not check logs. Output your reply and wait for the user to respond.

The automation runs in background. Telegram handles all progress and result notifications automatically.

### Step 3 — When user comes back ("done?", "book it", "what happened?", "next step")

First check if still running:

```
exec { "command": "bash ~/android-automation-agent/scripts/check_busy.sh" }
```

- `BUSY: ...` → "Still running, watch Telegram."
- `FREE` → Read the result:

```
exec { "command": "cat ~/storage/shared/android_agent/last_result.json" }
```

Parse the JSON (`success`, `summary`). Report to user. Continue to next step if needed.

### Hard rules

- **NEVER use `process/log`** — it causes your turn to timeout. Do not use it for anything.
- **NEVER use `process/poll`** — it returns nothing useful for this pattern.
- **After getting a session ID → reply once → stop.** Do not call exec again. Do not verify. Do not loop.
- **NEVER loop checking the session** — the only check is `check_busy.sh`, once, when user asks.
- `last_result.json` is written when automation finishes. Read it then. Not before.

---

## SECTION 4 — Goal String Construction

### Format

The goal string you pass to `run.py` must be:
1. The user's words, lightly structured into a task
2. With ZERO substitutions, brand names, or assumptions you added

### Only add mechanical steps the user skipped

Acceptable additions:
- "Open [app name]" at the start (if the user named the app but didn't say "open")
- "tap the search bar" (mechanical UI navigation)
- "wait for results to load" (mechanical wait)

NOT acceptable:
- Renaming anything the user said
- Adding product brands, variants, sizes the user didn't specify
- Guessing how an app is structured (e.g. "go to Swiggy then tap Instamart")
- Adding "show me", "tell me", "read", "return" — the screenshot IS the answer

### For info requests ("what's the fare", "check my balance")

End the goal at the target screen. Never say "read the value" or "tell me the price".
The final screenshot is the answer — you will read it visually after the run.

- Bad: "Open Uber, tell me the fare to Koramangala"
- Good: "Open Uber, set destination to Koramangala, wait for ride options to load"

### For follow-up commands ("order it", "confirm", "go ahead")

Read `~/storage/shared/android_agent/last_result.json` to see what the previous run did.
Include that context at the START of the new goal, then append the user's current command.

- Bad: "complete checkout"
- Good: "Nandini milk is already in the Blinkit cart. Open Blinkit, go to cart, proceed to checkout"

### Fresh tasks vs follow-up tasks

**Fresh task** = user names an app or starts a new workflow from scratch.
- Examples: "Open Uber", "Search for shoes on Amazon", "Check my Gmail"
- The goal string should start with "Open [app]" — the agent will navigate from whatever is on screen.

**Follow-up task** = user continues a workflow that's already on screen.
- Examples: "book it", "confirm the order", "select the cheapest option", "go ahead"
- The goal string should describe the CURRENT screen state + what to do next.
- The wake script will NOT press Home or Back — the app stays exactly where it was.
- Example goal: "Rapido ride booking screen is showing with ride details. Tap the Book Now button."

**How to detect follow-up tasks:**
1. The user's message implies continuation ("do it", "confirm", "book it", "go ahead", "next", "order")
2. There is a recent `last_result.json` (check modified time — if less than 10 minutes old, it's relevant)
3. The previous task succeeded (`success: true`)

When all three are true → this is a follow-up. Read `last_result.json` for context and construct the goal accordingly. Do NOT add "Open [app]" — the app is already open.

### If ambiguous → ASK. Do not guess.

---

## SECTION 5 — Complex Task Decomposition Protocol

For any task involving 3+ screens, multiple apps, or checkout/payment:

### Step-by-step protocol

1. **Collect all info first** — ask the user for every missing detail BEFORE starting any automation
2. **Decompose into atomic runs** — each run should do ONE thing (open app, search, add to cart, etc.)
3. **Run step 1** → wait for result JSON → verify success
4. **If success** → read last_result.json → construct next goal WITH context → run step 2
5. **If failure** → retry once with a rephrased goal → if still failing, report to user and ask how to proceed

### Example decomposition — "Order milk from Blinkit"

```
Step 1: Collect info
  - Check preferences.json → found: Nandini Toned Milk 500ml, app: Blinkit
  - No need to ask user

Step 2: Run #1
  Goal: "Open Blinkit, search for Nandini Toned Milk 500ml"
  --steps 25 --json
  → Wait for result → Check success

Step 3: Run #2
  Read last_result.json for context.
  Goal: "Search results for Nandini milk are showing on Blinkit. Tap the Nandini Toned Milk 500ml product and tap Add to Cart"
  --steps 20 --json
  → Wait for result → Check success

Step 4: Run #3
  Goal: "Item is in Blinkit cart. Open cart, verify items, proceed to checkout"
  --steps 20 --json
  → Wait for result → Check success

Step 5: Run #4
  Goal: "Blinkit checkout screen is showing. Select payment method and place the order"
  --steps 25 --json
  → Wait for result → Task complete
```

### Step count guidelines

- Simple tasks (open app, single search): `--steps 15`
- Medium tasks (search + navigate + tap): `--steps 25`
- Complex tasks (multi-screen flows): `--steps 35`
- Checkout/payment flows: `--steps 25`

---

## SECTION 6 — Check Current Screen

When user asks "what's on screen?", "what's happening?", or "show me the phone":

```bash
cd ~/android-automation-agent && python run.py --screenshot
```

Takes a fresh ADB screenshot and sends it to Telegram automatically. Never use `last_screenshot.png` — it's from a previous run.

---

## SECTION 7 — Failure Recovery

When `run.py --json` returns `"success": false`, read the `summary` field to understand what failed, then act:

| Failure pattern | Recovery action |
|---|---|
| Element not found / off-screen | Retry with "scroll down first, then [original goal]" |
| Same step failed twice | Rephrase goal more specifically, or split into a smaller run |
| Checkout / payment failed | Retry with current screen state described at the start of the goal |
| Popup or overlay not tapping | Break into two runs: one to reach the popup, one to tap the button |
| Tap loop (summary says "loop detected") | Retry with a different approach — "scroll to reveal", "swipe up first" |
| `max_steps_reached` | The task was too complex for one run — decompose and retry from where it stopped |
