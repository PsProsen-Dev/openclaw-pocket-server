"""
android-ai-agent — AI agent for Android automation via ADB.
Loads .env automatically on any import so API keys are always available.
"""

try:
    from dotenv import load_dotenv

    load_dotenv()
except ImportError:
    pass  # python-dotenv not installed; env vars must be set manually
