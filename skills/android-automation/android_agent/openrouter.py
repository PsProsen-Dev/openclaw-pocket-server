"""
OpenRouter client — pure requests, no OpenAI SDK.
Uses the OpenRouter REST API directly so Termux arm64 installs cleanly
(the openai package pulls jiter which requires Rust to build).
"""

import json
import os

import requests

_COMPLETIONS_URL = "https://openrouter.ai/api/v1/chat/completions"
_HEADERS_COMMON = {
    "HTTP-Referer": "https://github.com/Mohd-Mursaleen/android-automation-agent",
    "X-Title": "android-automation-agent",
    "Content-Type": "application/json",
}


def _api_key() -> str:
    """
    Return the OpenRouter API key from the environment.

    Returns:
        API key string.

    Raises:
        ValueError: If OPENROUTER_API_KEY is not set.
    """
    key = os.environ.get("OPENROUTER_API_KEY", "")
    if not key:
        raise ValueError(
            "OPENROUTER_API_KEY environment variable not set.\n"
            "Get your key at https://openrouter.ai/keys\n"
            "Then add it to your .env file."
        )
    return key


def _post(payload: dict) -> dict:
    """
    POST to the OpenRouter completions endpoint.

    Args:
        payload: JSON-serialisable request body.

    Returns:
        Parsed JSON response dict.

    Raises:
        requests.HTTPError: On 4xx/5xx responses.
        ValueError: If OPENROUTER_API_KEY is missing.
    """
    headers = {**_HEADERS_COMMON, "Authorization": f"Bearer {_api_key()}"}
    resp = requests.post(_COMPLETIONS_URL, headers=headers, json=payload, timeout=60)
    resp.raise_for_status()
    return resp.json()


def vision_completion(
    model: str,
    system_prompt: str,
    user_text: str,
    image_base64: str,
    temperature: float = 0.2,
    max_tokens: int = 1024,
) -> str:
    """
    Send a vision request (text + image) to OpenRouter.

    Args:
        model: OpenRouter model ID, e.g. "google/gemini-2.5-flash-preview".
        system_prompt: System message content.
        user_text: User message text accompanying the image.
        image_base64: Base64-encoded PNG screenshot.
        temperature: Sampling temperature.
        max_tokens: Maximum response tokens.

    Returns:
        Stripped response text from the model.

    Raises:
        ValueError: If OPENROUTER_API_KEY is missing.
        requests.HTTPError: On API errors.
    """
    data = _post({
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "messages": [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_text},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/png;base64,{image_base64}"
                        },
                    },
                ],
            },
        ],
    })
    return data["choices"][0]["message"]["content"].strip()


def text_completion(
    model: str,
    system_prompt: str,
    user_text: str,
    temperature: float = 0.2,
    max_tokens: int = 1024,
) -> str:
    """
    Send a text-only request to OpenRouter.

    Args:
        model: OpenRouter model ID.
        system_prompt: System message content.
        user_text: User message text.
        temperature: Sampling temperature.
        max_tokens: Maximum response tokens.

    Returns:
        Stripped response text from the model.

    Raises:
        ValueError: If OPENROUTER_API_KEY is missing.
        requests.HTTPError: On API errors.
    """
    data = _post({
        "model": model,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ],
    })
    return data["choices"][0]["message"]["content"].strip()
