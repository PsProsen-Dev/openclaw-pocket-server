#!/usr/bin/env python3
"""Quick check: is ADB connected? Is OpenRouter API key valid?"""
try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass

from android_agent.utils.check import run_check
import sys

ok = run_check()
sys.exit(0 if ok else 1)
