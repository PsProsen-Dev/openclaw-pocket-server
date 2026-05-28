"""
Summarizer node — verifies whether the last action achieved its intent.

Takes a fresh screenshot after execution and asks a cheap/fast LLM whether
the screen now reflects what the action was supposed to accomplish.
Tracks consecutive failures per subgoal; marks it failed after 3 in a row.

LLM: google/gemini-3-flash-preview via OpenRouter (vision).
"""

import json
import logging
from typing import Optional

from android_agent.executor.android import AndroidExecutor
from android_agent.graph.config import config
from android_agent.graph.state import AgentState
from android_agent.openrouter import vision_completion

logger = logging.getLogger(__name__)
_MAX_CONSECUTIVE_FAILURES = 3

_SYSTEM_PROMPT = """\
You are a verification agent for Android automation.
You are shown a screenshot taken AFTER a single action was performed.

Your job: determine whether THAT SPECIFIC ACTION had a visible EFFECT on the screen.

KEY DISTINCTION — read carefully:
- "The button is visible" does NOT mean the tap succeeded.
- Success means the screen CHANGED as a result of the action.
- If a tap was performed but the screen looks IDENTICAL to before — that is a FAILURE.
  The tap did not register, or hit the wrong element, or the element is not responding.

Examples of SUCCESS:
- A tap was performed → a new screen, dialog, or page appeared
- A tap on a button → the button changed state (highlighted, loading spinner, etc.)
- A swipe was performed → the content scrolled and new items are visible
- type_text was performed → text appeared in the field
- press_back → the previous screen is showing

Examples of FAILURE:
- A tap was performed → the screen looks EXACTLY the same as before the tap
- A tap on a "Book" button → the booking screen is still showing with the same button
  (the button didn't respond — this is a FAILURE even though the button is visible)
- The same screen is shown with no visible change at all
- An error dialog or toast message appeared

IMPORTANT: If the action was a tap and the screen appears unchanged, that is ALWAYS
a failure. The button being visible does not mean the tap worked. Taps that work
cause visible screen transitions.

Return ONLY this JSON, no other text:
{"success": true, "observation": "brief description of what changed on screen"}
or
{"success": false, "observation": "screen appears unchanged after tap — tap did not register"}"""


def summarizer_node(state: AgentState, executor: AndroidExecutor) -> AgentState:
    """
    Take a fresh screenshot and verify the last action succeeded.

    Tracks consecutive failures in state.scratchpad["current_subgoal_failures"].
    If failures reach _MAX_CONSECUTIVE_FAILURES, marks the running subgoal failed.

    Args:
        state: Current agent state; reads action_history and structured_decision.
        executor: Used to capture the post-action screenshot.

    Returns:
        Updated state; may mark a subgoal as failed on repeated failures.
    """
    last_action = state.action_history[-1] if state.action_history else "(unknown)"
    current_sg = _get_running_subgoal(state)
    if current_sg is None:
        return state  # nothing to verify

    # Take fresh screenshot for verification
    screenshot_b64 = executor.screenshot("summarizer", as_base64=True)
    if not screenshot_b64:
        logger.warning("Summarizer: screenshot failed — skipping verification")
        return state

    # Keep state current — the post-action screenshot replaces the pre-action one
    # so the runner always has the most recent screen for notifications and next cycle
    state.latest_screenshot_b64 = screenshot_b64

    result = _verify(last_action, screenshot_b64)
    success = result.get("success", True)  # default optimistic on parse failure
    observation = result.get("observation", "")

    state.agents_thoughts.append(
        f"[summarizer] {'✓' if success else '✗'} {observation}"
    )
    logger.debug(f"Summarizer: success={success} obs={observation}")

    if success:
        # Reset failure counter on success
        state.scratchpad["current_subgoal_failures"] = 0
    else:
        count = state.scratchpad.get("current_subgoal_failures", 0) + 1
        state.scratchpad["current_subgoal_failures"] = count
        logger.warning(
            f"Summarizer: action failed (attempt {count}/{_MAX_CONSECUTIVE_FAILURES})"
        )
        if count >= _MAX_CONSECUTIVE_FAILURES:
            current_sg.status = "failed"
            current_sg.failure_reason = (
                f"Action failed {count} times in a row. Last: {observation}"
            )
            state.action_history.append(
                f"❌ FAILED after {count} attempts: {current_sg.description}"
            )
            logger.warning(f"Subgoal marked failed: {current_sg.description}")

    return state


def _get_running_subgoal(state: AgentState):
    """Return the first subgoal with status 'running', or None."""
    for sg in state.subgoal_plan:
        if sg.status == "running":
            return sg
    return None


def _verify(last_action: str, screenshot_b64: str) -> dict:
    """
    Ask the LLM whether the specific action visibly changed the screen.

    Args:
        last_action: Description of what was just executed.
        screenshot_b64: Fresh screenshot taken after the action.

    Returns:
        Dict with 'success' (bool) and 'observation' (str).
    """
    user_text = (
        f"Action just performed: {last_action}\n\n"
        "Did this action execute and visibly change the screen?"
    )
    try:
        raw = vision_completion(
            model=config.SUMMARIZER_MODEL,
            system_prompt=_SYSTEM_PROMPT,
            user_text=user_text,
            image_base64=screenshot_b64,
            max_tokens=128,
        )
        return _parse_json(raw)
    except Exception:
        logger.exception("Summarizer LLM call failed")
        return {"success": True, "observation": "verification unavailable"}


def _parse_json(text: str) -> dict:
    """Parse JSON from the LLM, stripping markdown fences if present."""
    s = text.strip()
    if s.startswith("```"):
        lines = s.split("\n")
        inner = lines[1:-1] if lines[-1].strip() == "```" else lines[1:]
        s = "\n".join(inner).strip()
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        logger.warning(f"Summarizer JSON parse failed: {text[:200]}")
        return {"success": True, "observation": text[:200]}
