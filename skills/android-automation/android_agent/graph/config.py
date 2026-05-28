"""
Central configuration for the agent graph.
All values are overridable via environment variables (or .env file).
"""

import os


class Config:
    # OpenRouter
    OPENROUTER_API_KEY: str = os.environ.get("OPENROUTER_API_KEY", "")
    OPENROUTER_BASE_URL: str = "https://openrouter.ai/api/v1"

    # Models — set in .env to override without touching source code
    PLANNER_MODEL: str = os.environ.get(
        "PLANNER_MODEL", "google/gemini-3-flash-preview"
    )
    CORTEX_MODEL: str = os.environ.get("CORTEX_MODEL", "google/gemini-3-flash-preview")
    SUMMARIZER_MODEL: str = os.environ.get(
        "SUMMARIZER_MODEL", "google/gemini-3-flash-preview"
    )
    FALLBACK_MODEL: str = os.environ.get(
        "FALLBACK_MODEL", "google/gemini-3-flash-preview"
    )

    # Automation
    DEFAULT_MAX_STEPS: int = int(os.environ.get("MAX_STEPS", "25"))
    STEP_DELAY_SECONDS: float = float(os.environ.get("STEP_DELAY", "2.0"))
    LOG_LEVEL: str = os.environ.get("LOG_LEVEL", "INFO")


config = Config()
