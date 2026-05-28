"""
Cortex node — the decision brain.

Receives screenshot + exact UI element coordinates (from Contextor) + the
current subgoal + history, and returns exactly ONE tool call with precise
coordinates. Critically: it MUST use coordinates from the UI tree, never
guess visually.

LLM: google/gemini-3-flash-preview via OpenRouter (vision).
"""

import json
import logging
import re as _re
from typing import Optional

from android_agent.graph.config import config
from android_agent.graph.state import AgentState
from android_agent.openrouter import vision_completion

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """\
You are the Cortex — the decision brain of an Android automation agent.

You receive:
1. A screenshot of the current Android screen
2. UI elements with their EXACT pixel center coordinates (from the accessibility tree)
3. Whether the UI tree is complete or empty/sparse
4. The current subgoal you must complete
5. Recent action history

Your job: decide the single next action to take.

== COORDINATE RULES ==

MODE A — UI tree available (normal mode):
  When the UI elements list has entries, ALWAYS use exact coordinates from the list.
  Never estimate coordinates from the screenshot when the tree has what you need.

MODE B — UI tree empty/sparse (vision fallback mode):
  When the prompt says "UI TREE IS EMPTY/SPARSE — USE VISION MODE", the accessibility
  tree could not read this screen (popups, overlays, WebViews, Flutter, custom layers).
  In this mode:
  - You MUST estimate coordinates from the screenshot. This is expected and correct.
  - Look at the screenshot carefully and identify the target element visually.
  - Estimate coordinates based on the element's visual center position.
  - The screenshot is full resolution — coordinates map directly to screen pixels.
  - If your first tap doesn't work, SHIFT coordinates on retry:
    * Try ±50px horizontally and ±100-200px vertically
    * Buttons near the bottom of the screen are usually at y > 2000 on tall screens
    * Never tap the exact same coordinates twice if the screen didn't change

== REPETITION AVOIDANCE ==

CRITICAL: Look at your recent action history. If you see yourself tapping the same
coordinates (within ±30px) more than 2 times:
  - STOP tapping that location. It is not working.
  - Try a DIFFERENT approach:
    * Shift coordinates significantly (±100-200px)
    * Try scrolling to reveal the element in a different position
    * Try using gesture() instead of tap() — some overlays respond to swipe/gesture but not tap
    * If nothing works after 3 different attempts, mark_subgoal_failed with a clear reason

== AVAILABLE TOOLS ==

  tap(x, y)
    Tap at coordinates. Use UI tree coords in Mode A, visual estimation in Mode B.

  type_text(text, press_enter)
    Type into the focused field.
    press_enter: true = submit after typing. false (DEFAULT) = just type.

  clear_field()
    Clear all text in the currently focused input field.
    Use BEFORE type_text when the field already has text you want to replace.

  gesture(x1, y1, x2, y2, duration_ms)
    Universal gesture primitive.
    SCROLL DOWN:  gesture(540, 1400, 540, 600,  duration_ms=150)
    SCROLL UP:    gesture(540, 600,  540, 1400, duration_ms=150)
    SWIPE LEFT:   gesture(900, 1000, 100, 1000, duration_ms=150)
    SWIPE RIGHT:  gesture(100, 1000, 900, 1000, duration_ms=150)
    SLIDER DRAG:  Use [SLIDER] annotation bounds, duration_ms=800

  long_press(x, y, duration_ms)
    Long press for context menus, text selection. Default 1000ms.

  press_key(key)
    Send key event: "back", "home", "enter", "recent_apps"

  wait(seconds)
    Wait for UI to settle (max 5s).

  mark_subgoal_complete(reason)
    Current subgoal is achieved and visible on screen.

  mark_subgoal_failed(reason)
    Subgoal is truly impossible after multiple attempts.

== TEXT FIELD RULES ==
- Field has existing text + you need different text → clear_field first, then type_text
- Empty field → just type_text
- Only use press_enter=true when submitting search or sending messages

== SEARCH & SUGGESTION HANDLING ==

After typing in a search bar, address field, or any field that shows autocomplete suggestions:
1. The system automatically waits 4 seconds after typing for suggestions to load.
2. When you get your next screenshot, the suggestions WILL be loaded. Read them carefully.
3. Evaluate ALL visible suggestions and tap the one that BEST matches the intent.
4. Do NOT blindly tap the first suggestion. Compare each option to what was typed.
5. If no suggestion matches well, try clearing the field and retyping with different
   spelling or a shorter query.

Example — user wants "Global Calcium Koramangala":
  After typing, you might see suggestions like:
    - "Global Calcium Products Pvt Ltd, Koramangala" ← best match, tap this
    - "Calcium Supplements Store, MG Road" ← wrong, ignore
    - "Global Hospital, Koramangala" ← partial match but wrong place, ignore
  Always pick the closest match to the original search text.

Return ONLY this JSON, no markdown, no explanation:
{
  "tool": "tap",
  "args": {"x": 540, "y": 1200},
  "reason": "Tapping the Settings icon at exact coordinates from UI tree",
  "thought": "I can see Settings in the UI elements list at [540,1200]"
}"""


def cortex_node(state: AgentState) -> AgentState:
    """
    Decide the next action using the current screenshot and UI element list.

    Args:
        state: Must have latest_screenshot_b64, latest_ui_hierarchy,
               and a running subgoal in subgoal_plan.

    Returns:
        Updated state with structured_decision populated.
    """
    current_sg = _get_running_subgoal(state)
    if current_sg is None:
        logger.warning("Cortex called but no running subgoal found")
        state.structured_decision = {"tool": "wait", "args": {"seconds": 1}}
        return state

    user_text = _build_prompt(state, current_sg.description)

    decision = _call_llm(user_text, state.latest_screenshot_b64)
    if decision is None:
        # Safe fallback: wait and retry next iteration
        decision = {
            "tool": "wait",
            "args": {"seconds": 2},
            "reason": "LLM call failed, waiting",
            "thought": "",
        }

    state.structured_decision = decision
    state.agents_thoughts.append(
        f"[cortex] {decision.get('tool')} — {decision.get('reason', '')}"
    )
    return state


def _get_running_subgoal(state: AgentState):
    """Return the first subgoal with status 'running', or None."""
    for sg in state.subgoal_plan:
        if sg.status == "running":
            return sg
    return None


def _extract_recent_tap_coords(history: list[str]) -> list[tuple[int, int]]:
    """Extract (x, y) coordinates from recent TAP entries in action history."""
    coords = []
    for entry in history:
        if entry.startswith("TAP "):
            match = _re.search(r"TAP \((\d+),\s*(\d+)\)", entry)
            if match:
                coords.append((int(match.group(1)), int(match.group(2))))
    return coords


def _has_repetition(coords: list[tuple[int, int]], threshold: int = 30) -> bool:
    """
    Check if the last 3+ taps hit approximately the same coordinates.

    Args:
        coords: List of (x, y) tap coordinates in order.
        threshold: Max pixel distance to consider "same location".

    Returns:
        True if there are 3+ taps within threshold px of each other.
    """
    if len(coords) < 3:
        return False
    last_three = coords[-3:]
    base_x, base_y = last_three[0]
    for x, y in last_three[1:]:
        if abs(x - base_x) > threshold or abs(y - base_y) > threshold:
            return False
    return True


def _build_prompt(state: AgentState, subgoal: str) -> str:
    """Build the user message for Cortex, including UI elements and history."""
    history = "\n".join(state.action_history[-5:]) or "(none yet)"
    thoughts = "\n".join(state.agents_thoughts[-3:]) or "(none)"
    focused = state.focused_app or "unknown"

    # Vision fallback signal
    if not state.ui_tree_available:
        ui_section = (
            "⚠️ UI TREE IS EMPTY/SPARSE — USE VISION MODE ⚠️\n"
            "The accessibility tree returned few or no elements for this screen.\n"
            "This is normal for popups, overlays, WebViews, and custom UI layers.\n"
            "You MUST estimate coordinates from the screenshot.\n"
            "Look at the screenshot carefully and identify button positions visually.\n"
            "Remember: on tall screens (1080x2340), buttons at the bottom are at y > 2000."
        )
        partial = state.latest_ui_hierarchy
        if partial and partial not in ("(no labelled elements found)", "(UI tree unavailable — using screenshot only)"):
            ui_section += f"\n\nPartial UI elements (may be incomplete):\n{partial}"
    else:
        ui_section = f"UI Elements (USE THESE EXACT COORDINATES):\n{state.latest_ui_hierarchy}"

    # Repetition detection warning
    repeat_warning = ""
    if len(state.action_history) >= 3:
        recent_taps = _extract_recent_tap_coords(state.action_history[-5:])
        if _has_repetition(recent_taps):
            repeat_warning = (
                "\n\n⚠️ REPETITION DETECTED: You have tapped similar coordinates multiple times "
                "without the screen changing. You MUST try a DIFFERENT approach:\n"
                "- Shift coordinates by ±100-200px\n"
                "- Try gesture() instead of tap()\n"
                "- Try scrolling first\n"
                "- Or mark_subgoal_failed if nothing works\n"
                "Do NOT tap the same location again."
            )

    return (
        f"Current subgoal: {subgoal}\n\n"
        f"{ui_section}\n\n"
        f"Focused app: {focused}\n\n"
        f"Recent actions (last 5):\n{history}\n\n"
        f"Recent thoughts:\n{thoughts}"
        f"{repeat_warning}\n\n"
        "Look at the screenshot and decide the next action. Return JSON only."
    )


def _call_llm(user_text: str, screenshot_b64: Optional[str]) -> Optional[dict]:
    """
    Call the Cortex LLM and parse the JSON response.

    Args:
        user_text: Assembled prompt text.
        screenshot_b64: Base64 PNG screenshot.

    Returns:
        Parsed decision dict, or None on failure.
    """
    if not screenshot_b64:
        logger.error("Cortex: no screenshot available")
        return None
    try:
        raw = vision_completion(
            model=config.CORTEX_MODEL,
            system_prompt=_SYSTEM_PROMPT,
            user_text=user_text,
            image_base64=screenshot_b64,
            max_tokens=512,
        )
        return _parse_json(raw)
    except Exception:
        logger.exception("Cortex LLM call failed")
        return None


def _parse_json(text: str) -> Optional[dict]:
    """Strip markdown fences and parse JSON."""
    s = text.strip()
    if s.startswith("```"):
        lines = s.split("\n")
        inner = lines[1:-1] if lines[-1].strip() == "```" else lines[1:]
        s = "\n".join(inner).strip()
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        logger.error(f"Cortex JSON parse failed: {text[:300]}")
        return None
