> **Source:** [Mohd-Mursaleen/android-automation-agent](https://github.com/Mohd-Mursaleen/android-automation-agent) (MIT) — Integrated into OCA by RTX⚡ Swarm

# Android Automation Agent

> **Automate any Android device using natural language and AI.**  
> The open-source AI agent for Android automation — control your phone with plain English.

[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![OpenRouter](https://img.shields.io/badge/LLM-OpenRouter-orange.svg)](https://openrouter.ai)
[![Termux Compatible](https://img.shields.io/badge/Termux-compatible-brightgreen.svg)](https://termux.dev)
[![GitHub stars](https://img.shields.io/github/stars/Mohd-Mursaleen/android-automation-agent?style=social)](https://github.com/Mohd-Mursaleen/android-automation-agent)

**Android Automation Agent** is an open-source AI-powered tool that automates any Android device using natural language commands. Built by [Mohd Mursaleen](https://github.com/Mohd-Mursaleen), it combines vision AI models with Android's UI accessibility tree to reliably execute complex multi-step tasks — no manual scripting, no brittle XPath selectors, no app-specific code required.

**Use cases:** Android app testing, mobile automation, ADB scripting, Android bot, UI automation, automated testing, Android RPA, mobile QA, accessibility testing, and more.

```bash
# E-commerce automation
python run.py "Open Amazon, search for 'wireless earbuds under 2000', sort by customer reviews, and add the top-rated one to cart"

# Food delivery
python run.py "Open Swiggy, search for 'butter chicken', find a restaurant with 4+ stars, and add it to cart"

# Social media
python run.py "Open Instagram, go to reels, like the first 3 videos, then open my profile and check followers count"

# Productivity
python run.py "Open Gmail, find the latest email from Amazon, and forward it to myself with subject 'Order Confirmation'"
```

---

## How It Works

The agent uses a 6-node state machine that plans, executes, and verifies each action:

```
PLANNER → ORCHESTRATOR → CONTEXTOR → CORTEX → EXECUTOR → SUMMARIZER
                              ↑___________________________|
```

| Node             | Role |
| ---------------- | ---- |
| **Planner**      | Breaks your goal into 2–5 verifiable subgoals |
| **Orchestrator** | Manages subgoal execution order and tracks progress |
| **Contextor**    | Captures screenshot + UI tree with exact element coordinates |
| **Cortex**       | Decides the next action using vision + coordinate data |
| **Executor**     | Sends ADB commands (tap, swipe, type, keypress) |
| **Summarizer**   | Verifies action success before proceeding |

**Why it works:** The Contextor combines screenshots with `uiautomator dump` to provide exact pixel coordinates for every UI element. The Cortex never guesses — it uses real coordinate data.

---

## Requirements

- **Android device** with Developer Options + USB/Wireless Debugging enabled
- **ADB** installed on your machine
- **Python 3.10+**
- **OpenRouter API key** — free at [openrouter.ai/keys](https://openrouter.ai/keys)

---

## Quick Start

### Linux / macOS

```bash
# Install ADB
# macOS:  brew install android-platform-tools
# Ubuntu: sudo apt install adb

git clone https://github.com/Mohd-Mursaleen/android-automation-agent
cd android-automation-agent
chmod +x setup.sh && ./setup.sh

# Add your API key
echo "OPENROUTER_API_KEY=your_key_here" > .env

# Connect device and verify
adb devices
python check.py
```

### Windows

```bash
# WSL recommended — or native Python 3.10+ with ADB from:
# https://developer.android.com/studio/releases/platform-tools

git clone https://github.com/Mohd-Mursaleen/android-automation-agent
cd android-automation-agent
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env   # then edit to add your API key
python check.py
```

### Termux (on-device, no PC required)

```bash
pkg install python android-tools git
git clone https://github.com/Mohd-Mursaleen/android-automation-agent
cd android-automation-agent && ./setup.sh
echo "OPENROUTER_API_KEY=your_key" > .env
adb connect 127.0.0.1:5555
python check.py
```

> **Note:** Fully Termux-compatible — pure Python, no Rust/C++ dependencies.

---

## Usage

```bash
source .venv/bin/activate   # Linux/macOS
# .venv\Scripts\activate    # Windows
```

### Complex Multi-Step Tasks

```bash
# Shopping workflow with filters
python run.py "Open Flipkart, search for 'running shoes size 10', filter by rating 4+, sort by price low to high, and add the first Nike shoe to cart"

# Travel booking
python run.py "Open MakeMyTrip, search for flights from Delhi to Mumbai on 15th January, select the cheapest non-stop flight, and proceed to booking"

# Banking
python run.py "Open PayTM, check my balance, then send 500 rupees to the contact named 'Rahul'"

# Content creation
python run.py "Open YouTube Studio, go to my latest video, check the analytics, and reply 'Thank you!' to the top comment"
```

### Options

```bash
# Increase steps for longer tasks
python run.py "Complete a multi-step checkout process" --steps 50

# Quiet mode (less output)
python run.py "Open Settings" --quiet

# Target specific device
python run.py "Open Camera" --device emulator-5554

# Health check
python run.py --check
```

---

## Configuration

```bash
cp .env.example .env
```

```env
# Required
OPENROUTER_API_KEY=your_key_here

# Optional — override default models
PLANNER_MODEL=google/gemini-3-flash-preview
CORTEX_MODEL=google/gemini-3-flash-preview
SUMMARIZER_MODEL=google/gemini-3.1-flash-lite-preview

# Optional — tuning
MAX_STEPS=25
STEP_DELAY=2.0
LOG_LEVEL=INFO
```

---

## Models

| Agent      | Default Model                          | Purpose                  |
| ---------- | -------------------------------------- | ------------------------ |
| Planner    | `google/gemini-3-flash-preview`        | Task decomposition       |
| Cortex     | `google/gemini-3-flash-preview`        | Vision + action decision |
| Summarizer | `google/gemini-3.1-flash-lite-preview` | Action verification      |

All LLM calls route through [OpenRouter](https://openrouter.ai) — use any supported model by changing your `.env`.

---

## Python API

```python
from android_agent.graph.runner import run_task

state = run_task(
    goal="Open Chrome, search for 'Python tutorials', and open the first result",
    max_steps=30,
    quality=75,      # screenshot quality (50-100)
    verbose=True,
    device_id=None,  # auto-detect
)

if state.task_complete:
    print(f"Done in {state.step_count} steps")
    print("Actions:", state.action_history)
else:
    print(f"Failed: {state.failure_reason}")
```

---

## Project Structure

```
android-automation-agent/
├── android_agent/
│   ├── openrouter.py           # LLM client (vision + text)
│   ├── executor/
│   │   └── android.py          # ADB commands (tap, swipe, type)
│   ├── graph/
│   │   ├── config.py           # Model & env configuration
│   │   ├── state.py            # AgentState dataclass
│   │   ├── runner.py           # Main execution loop
│   │   └── nodes/              # State machine nodes
│   │       ├── planner.py
│   │       ├── orchestrator.py
│   │       ├── contextor.py
│   │       ├── cortex.py
│   │       ├── executor.py
│   │       ├── summarizer.py
│   │       └── convergence.py
│   └── utils/
│       └── check.py
├── run.py                      # CLI entry point
├── check.py                    # Health check script
├── setup.sh                    # One-command setup
├── requirements.txt
├── .env.example
└── pyproject.toml
```

---

## Contributing

PRs welcome! Please open an issue first for major changes.

---

## Author

Built with ❤️ by **[Mohd Mursaleen](https://github.com/Mohd-Mursaleen)**

- GitHub: [@Mohd-Mursaleen](https://github.com/Mohd-Mursaleen)
- Project: [android-automation-agent](https://github.com/Mohd-Mursaleen/android-automation-agent)

---

## License

MIT — free to use, modify, and distribute.

---

## Keywords

Android automation, Android AI agent, ADB automation, mobile automation, Android bot, Android testing, UI automation, Android RPA, Termux automation, mobile AI agent, Android scripting, natural language automation, LLM Android, Gemini Android, OpenRouter, Android accessibility, mobile testing framework, Android task automation, no-code Android automation, AI-powered Android control
