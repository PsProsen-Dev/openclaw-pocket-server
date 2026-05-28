"""
Health check utility — verifies ADB connectivity and OpenRouter API key.
Called by check.py (standalone) and run.py --check.
"""

import os
import subprocess


def run_check() -> bool:
    """
    Check ADB and OpenRouter API key. Prints results to stdout.

    Returns:
        True if all checks passed, False otherwise.
    """
    print("\nandroid-ai-agent health check\n")

    adb_ok = _check_adb()
    api_ok = _check_openrouter()

    print()
    if adb_ok and api_ok:
        print("All checks passed — ready to run!\n")
    else:
        print("Fix the issues above before running tasks.\n")

    return adb_ok and api_ok


def _check_adb() -> bool:
    """Check whether at least one Android device is reachable via ADB."""
    print("Checking ADB...")
    device_lines = []
    try:
        result = subprocess.run(
            ["adb", "devices"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        device_lines = [
            l
            for l in result.stdout.strip().split("\n")[1:]
            if l.strip() and "offline" not in l
        ]
        if device_lines:
            print(f"  OK — {len(device_lines)} device(s) connected:")
            for line in device_lines:
                print(f"     -> {line.strip()}")
        else:
            print("  FAIL — no devices found")
            print("     Run: adb connect 127.0.0.1:5555")
    except FileNotFoundError:
        print("  FAIL — adb not installed")
        print("     Termux: pkg install android-tools")
        print("     macOS:  brew install android-platform-tools")
    return bool(device_lines)


def _check_openrouter() -> bool:
    """Verify the OpenRouter API key works with a minimal test call."""
    print("Checking OpenRouter API key...")
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        print("  FAIL — OPENROUTER_API_KEY not set")
        print("     Add it to your .env file (see .env.example)")
        return False

    try:
        import requests

        resp = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "google/gemini-3-flash-preview",
                "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
                "max_tokens": 5,
            },
            timeout=15,
        )
        resp.raise_for_status()
        answer = resp.json()["choices"][0]["message"]["content"].strip()
        print(f"  OK — API connected (responded: {answer!r})")
        return True
    except Exception as exc:
        print(f"  FAIL — {exc}")
        return False
