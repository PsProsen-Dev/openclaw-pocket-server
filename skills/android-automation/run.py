#!/usr/bin/env python3
"""
android-ai-agent — run this file to start an automation task.

Usage:
    python run.py "Open Settings"
    python run.py "Open Instamart and search for milk" --steps 30
    python run.py "Open Settings" --json
    python run.py --check
"""
import argparse
import base64
import json
import logging
import os
import subprocess
import sys

# Load .env before any other import so API keys are available
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

# Artifact paths written after every run (best-effort, for OpenClaw)
_ARTIFACT_DIR = os.path.expanduser("~/storage/shared/android_agent")
_RESULT_PATH = os.path.join(_ARTIFACT_DIR, "last_result.json")
_SCREENSHOT_PATH = os.path.join(_ARTIFACT_DIR, "last_screenshot.png")


from android_agent.utils.telegram import notify_telegram as _tg


def _take_screenshot_b64() -> str:
    """
    Capture current screen via ADB and return as base64 PNG. Returns '' on failure.
    """
    try:
        result = subprocess.run(
            ["adb", "exec-out", "screencap", "-p"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15,
        )
        if result.returncode == 0 and result.stdout:
            return base64.b64encode(result.stdout).decode()
    except Exception:
        pass
    return ""


def _build_summary(state) -> str:
    """
    Build a human-readable summary from final agent state.

    Combines subgoal completion status, last action, and failure reason
    so OpenClaw can answer the user without inspecting the screenshot first.

    Args:
        state: Final AgentState from run_task().

    Returns:
        Single-paragraph summary string.
    """
    parts = []

    complete = [sg.description for sg in state.subgoal_plan if sg.status == "complete"]
    failed_sgs = [sg.description for sg in state.subgoal_plan if sg.status == "failed"]

    if complete:
        parts.append("Completed: " + "; ".join(complete) + ".")
    if failed_sgs:
        parts.append("Did not complete: " + "; ".join(failed_sgs) + ".")

    if state.action_history:
        parts.append(f"Last action: {state.action_history[-1]}.")

    if not state.task_complete and state.failure_reason:
        parts.append(f"Failure reason: {state.failure_reason}.")

    if not parts:
        return "Task completed successfully." if state.task_complete else "Task did not complete."

    return " ".join(parts)


def _write_artifacts(state, result: dict) -> None:
    """
    Write last_result.json and last_screenshot.png to shared storage.

    Best-effort: any I/O failure is silently swallowed so it never
    crashes or corrupts the main run result.

    Args:
        state: Final AgentState from run_task().
        result: The result dict that will also be printed in JSON mode.
    """
    try:
        os.makedirs(_ARTIFACT_DIR, exist_ok=True)

        with open(_RESULT_PATH, "w") as f:
            json.dump(result, f, indent=2)

        if state.latest_screenshot_b64:
            img_bytes = base64.b64decode(state.latest_screenshot_b64)
            with open(_SCREENSHOT_PATH, "wb") as f:
                f.write(img_bytes)
    except Exception:
        pass


def main():
    parser = argparse.ArgumentParser(
        description="android-ai-agent: AI-powered Android automation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python run.py "Open Settings"
  python run.py "Open Instamart and add milk to cart" --steps 40
  python run.py "Open Settings" --json
  python run.py --check
        """,
    )
    parser.add_argument(
        "goal",
        nargs="?",
        help="The task to perform on your Android device",
    )
    parser.add_argument(
        "--steps",
        type=int,
        default=25,
        metavar="N",
        help="Maximum number of steps (default: 25)",
    )
    parser.add_argument(
        "--device",
        default=None,
        metavar="SERIAL",
        help="ADB device serial (from: adb devices). Auto-detected if omitted.",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress step-by-step output",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_mode",
        help="Print one final JSON result to stdout; suppress all other output",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Verify ADB connection and OpenRouter API key, then exit",
    )
    parser.add_argument(
        "--screenshot",
        action="store_true",
        help="Take a screenshot of the current screen, send to Telegram, then exit",
    )

    args = parser.parse_args()

    if args.check:
        from android_agent.utils.check import run_check

        ok = run_check()
        sys.exit(0 if ok else 1)

    if args.screenshot:
        screen_b64 = _take_screenshot_b64()
        if screen_b64:
            _tg("📱 Current screen", screen_b64)
            print("Screenshot sent to Telegram.")
        else:
            print("ADB screenshot failed.", file=sys.stderr)
            sys.exit(1)
        sys.exit(0)

    if not args.goal:
        parser.print_help()
        sys.exit(1)

    # Suppress all logging in JSON mode so stdout carries only the result object
    if args.json_mode:
        logging.disable(logging.CRITICAL)

    from android_agent.graph.runner import run_task

    # TTS start announcement — best effort, Termux-specific
    try:
        subprocess.run(
            ["termux-tts-speak", f"Starting. {args.goal[:100]}"],
            timeout=5, check=False,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass

    # Notify Telegram that automation is starting (fires before any ADB action)
    _tg(f"🤖 Android Agent started\nGoal: {args.goal}\nMax steps: {args.steps}")

    # Wake and unlock the device before starting — idempotent, safe to always run
    _wake_script = os.path.expanduser("~/android-automation-agent/scripts/wake_and_unlock.sh")
    if os.path.exists(_wake_script):
        subprocess.run(["bash", _wake_script], timeout=15)

    # First screenshot — confirms screen is awake and shows starting state
    _initial_screen = _take_screenshot_b64()
    if _initial_screen:
        _tg(
            f"📱 Screen ready | Goal: {args.goal[:200]}",
            _initial_screen,
        )

    state = run_task(
        goal=args.goal,
        max_steps=args.steps,
        verbose=(not args.quiet and not args.json_mode),
        device_id=args.device,
    )

    # --- Determine error type (only set on failure) ---
    error = None
    if not state.task_complete:
        if state.step_count >= state.max_steps:
            error = "max_steps_reached"
        elif state.task_failed:
            error = state.failure_reason or "task_failed"
        else:
            error = "unknown"

    # --- Build result dict (field order matches documented JSON format) ---
    result = {
        "success": state.task_complete,
        "goal": args.goal,
        "steps": state.step_count,
    }
    if error:
        result["error"] = error
    result["summary"] = _build_summary(state)
    result["screenshot_path"] = _SCREENSHOT_PATH if state.latest_screenshot_b64 else None
    result["result_path"] = _RESULT_PATH

    # Write artifacts after every run — always, not just in JSON mode
    _write_artifacts(state, result)

    if args.json_mode:
        print(json.dumps(result))
        sys.stdout.flush()

    sys.exit(0 if state.task_complete else 1)


if __name__ == "__main__":
    main()
