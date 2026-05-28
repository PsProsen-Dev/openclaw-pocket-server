# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**android-ai-agent** is a Python framework for autonomous Android device automation via ADB, using LLMs routed through [OpenRouter](https://openrouter.ai). It runs on Termux (arm64) and requires zero Rust/C++ build dependencies.

## Setup

```bash
# Termux
pkg install python adb
git clone https://github.com/Mohd-Mursaleen/android-ai-agent && cd android-ai-agent
pip install -e .
export OPENROUTER_API_KEY="your-key-here"
python check.py

# macOS / Linux
chmod +x setup.sh && ./setup.sh
```

## Commands

```bash
# Health check
python check.py

# Run a task
python run.py "open Settings and show the Android version" --verbose
python run.py "Open Instamart, add milk to cart" --steps 40 --quiet

# python run.py options:
#   --steps N      hard cap on action count (default 25)
#   --device ID    ADB serial (auto-detected if omitted)
#   --quiet        suppress step-by-step output
#   --check        run health check only, then exit
#   --quality N    screenshot quality (default 100, no compression)
#   --screenshot   take screenshot, send to Telegram, exit (no automation)
```

**Testing:**

```bash
pytest
pytest tests/test_android.py
```

## Architecture

Three-component pipeline per action cycle:

1. **Executor** (`executor/android.py`) — takes a screenshot via `adb exec-out screencap -p`, compresses it by `image_quality` percent, returns base64. All ADB taps/swipes/types go through here.
2. **Planner** (`graph/nodes/planner.py`) — text-only LLM; breaks the goal into 2–5 ordered subgoals as JSON.
3. **Cortex** (`graph/nodes/cortex.py`) — vision LLM; receives screenshot + UI element list from Contextor, returns one JSON action.

All LLM calls go through `android_agent/openrouter.py` using the OpenAI-compatible SDK pointed at `https://openrouter.ai/api/v1`. Set `OPENROUTER_API_KEY` in the environment.

### Execution loop (`graph/runner.py`)

```
state = planner_node(state)          # build subgoal plan
while True:
    state = orchestrator_node(state) # activate next subgoal
    route = convergence_node(state)  # "end" / "replan" / "continue"
    if route == "end": break
    if route == "replan": state = planner_node(state); continue
    state = contextor_node(state, executor)   # screenshot + uiautomator dump
    state = cortex_node(state)               # decide next action
    state = executor_node.execute(state)     # run ADB command
    state = summarizer_node(state, executor) # verify action worked
```

### Lock / mutex system

Only one automation task can run at a time (single Android screen).

- **Lock file**: `~/storage/shared/android_agent/agent.lock`
- **Contents**: JSON with `pid`, `goal`, `started_at`
- **Acquired** by `run_task()` at start, **released** at end (including on crash via try/finally)
- **Stale detection**: If the lock file exists but the PID is dead, the lock is automatically cleaned
- **Busy check script**: `scripts/check_busy.sh` — returns exit 0 (`FREE`) or exit 1 (`BUSY: details`)
- **SKILL.md Step 0**: Iota must run `check_busy.sh` before every automation run

### Monitoring & Telegram notifications

Notifications are integrated directly into the Python runner — no external monitor scripts needed.

1. **Start notification** — sent by `run.py` before `run_task()` is called.
   Uses `urllib.request` (stdlib only). Includes goal string and max steps.

2. **Progress updates (every `_PROGRESS_EVERY` steps)** — sent by `runner.py` inside the
   main loop, after `summarizer_node` runs. Default: every 2 steps.
   Each update sends `state.latest_screenshot_b64` (the summarizer's fresh post-action
   screenshot) with a caption: step count, elapsed time, current subgoal, last action.

3. **Final result** — sent by `runner.py` in the `finally` block.
   Fires even if the run raised an exception or was cancelled.
   Takes one last fresh screenshot; falls back to `state.latest_screenshot_b64` on
   ADB failure. Includes success/failure emoji, step count, elapsed time,
   completed/failed subgoals, and failure reason if applicable.

`_notify_telegram()` in `runner.py` uses `urllib.request` (stdlib — no `requests` package).
`_PROGRESS_EVERY = 2` is a module-level constant in `runner.py`; change it to tune frequency.

### Screen wake behavior

`scripts/wake_and_unlock.sh` is a smart idempotent script:
- Checks `mWakefulness` via `dumpsys power` — only sends WAKEUP if screen is off
- Checks `deviceLocked` via `dumpsys trust` — only swipes if locked
- **Never presses Home or Back** — current app state is preserved
- Safe to run before every automation — does nothing if screen is already awake and unlocked
- The Planner handles navigation to the correct app via subgoals

### Coordinate scaling

Default quality is 100 (no compression, no scaling). If quality is reduced,
`AndroidExecutor.image_scale_factor = 100 / quality`. When screenshots are compressed to N% of original size, coordinates from visual analysis are in that smaller space. `click_at_a_point` multiplies by `image_scale_factor` to hit the correct physical pixels.

**Critical**: `uiautomator dump` returns real screen pixels, not compressed-image pixels. The executor node sets `self.executor.image_scale_factor = 1.0` before every tap to prevent double-scaling.

### Vision fallback mode

When `uiautomator dump` returns an empty or very sparse tree (common with popups,
overlays, WebViews, Flutter, React Native), the Contextor sets `state.ui_tree_available = False`.

In this mode:
- Cortex switches to vision-based coordinate estimation from the screenshot
- This is expected behavior, not a bug — many production apps use custom UI layers
  that are invisible to the Android accessibility tree
- Cortex will shift coordinates on retry attempts to avoid infinite tap loops
- The runner has a hard loop breaker: 4 identical taps in a row → forced subgoal failure

### Repetition detection

Two layers of protection against infinite tap loops:

1. **Cortex-level** — the prompt includes recent action history and warns Cortex
   if it detects 3+ taps at similar coordinates, instructing it to try different approaches
2. **Runner-level** — hard code check: if the last 4 actions are all TAPs within 50px
   of each other, the running subgoal is force-failed with a descriptive error

### Tools available to Cortex

| Tool | Args | Notes |
|------|------|-------|
| tap | x, y | MUST use UI tree coordinates |
| type_text | text, press_enter | press_enter defaults to false. Only true for search submit / message send |
| clear_field | (none) | Clears focused text field via backspaces. Use before type_text on non-empty fields |
| gesture | x1, y1, x2, y2, duration_ms | Scroll, swipe, slider drag |
| long_press | x, y, duration_ms | Context menus, text selection. Default 1000ms |
| press_key | key | "back", "home", "enter", "recent_apps" |
| wait | seconds | Max 5s. Use after loading triggers |
| mark_subgoal_complete | reason | When subgoal is done |
| mark_subgoal_failed | reason | When subgoal is impossible |

### Gesture primitive

All swipe/scroll/slider actions go through `gesture(x1, y1, x2, y2, duration_ms)`:

- Scroll: 150 ms
- Slider drag: 800 ms (slow is required — fast swipes are ignored by Android)

Contextor annotates sliders in the UI hierarchy as `[SLIDER bounds=x1,y1,x2,y2]` with explicit gesture coordinates so Cortex knows to use `duration_ms=800`.

### Post-typing suggestion delay

After every `type_text` action, the executor adds a 2-second extra delay on top of
the standard 2-second post-action delay. Total wait after typing: 4 seconds.
This lets search suggestions and autocomplete results load from the server before
the Summarizer takes a screenshot. The delay is unconditional — fires on every
`type_text` regardless of `press_enter` setting.

### Voice feedback (TTS)

`termux-tts-speak` is called automatically — no dispatcher action required.

- **Task start**: `run.py` calls it before `run_task()` with the first 100 chars of the goal.
- **Task complete**: `runner.py` calls it in the `finally` block — "Task complete." or "Task failed."

### Smart pre-flight (Section 2.5)

Before every run the dispatcher must reason through five questions:
1. What is the user actually asking for?
2. Fresh task or follow-up? (check `last_result.json` age + `success`)
3. What info is still missing?
4. How many runs will this take?
5. What step count is right?

Only then start the run pattern. This replaces the need for mid-task improvisation.

### No guardrails

The dispatcher does NOT stop before checkout or payment to confirm with the user.
Full autonomy: if the user asked to order/book/pay, execute the entire flow end-to-end.
- Checkout is just another screen — run it like any other
- If a step fails, retry once with rephrased goal; only escalate to user after two failures
- Never say "Should I proceed?" or "Want me to place the order?" unless the user explicitly said to stop and confirm first

### Module layout

```
android_agent/
├── __init__.py            # loads .env via python-dotenv
├── openrouter.py          # vision_completion() and text_completion() — all LLM I/O
├── executor/
│   ├── __init__.py        # Abstract Executor base class
│   └── android.py         # ADB-based implementation
├── graph/
│   ├── config.py          # Config class (reads from env)
│   ├── state.py           # AgentState + Subgoal dataclasses
│   ├── runner.py          # run_task() main loop
│   └── nodes/
│       ├── planner.py     # text LLM → subgoal JSON array
│       ├── orchestrator.py # activate next pending subgoal
│       ├── contextor.py   # screenshot + uiautomator dump → UI hierarchy string
│       ├── cortex.py      # vision LLM → single action JSON
│       ├── executor.py    # dispatch tool calls to android.py
│       ├── summarizer.py  # verify action succeeded (vision LLM)
│       └── convergence.py # route: end / replan / continue
└── utils/
    └── check.py           # ADB + OpenRouter health check
```

## Constraints

- **No Rust/C++ deps** — pure Python only; no `pyautogui`, `gradio`, `mlx`, `anthropic`, `google-generativeai`, `ollama`
- **OpenRouter only** — all LLM calls use `openai>=1.0.0` SDK with `base_url=https://openrouter.ai/api/v1`
- **Android only** — `executor/android.py` is the only executor
- **executor/android.py** — the stable ADB interface. Modify carefully and test after changes.
