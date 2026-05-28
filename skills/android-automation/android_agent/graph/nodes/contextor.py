"""
Contextor node — gathers the full screen context before every Cortex decision.

Does two things the old code never did:
  A. Takes a fresh screenshot (base64 PNG)
  B. Runs `adb shell uiautomator dump` to get EXACT element bounds from the
     accessibility tree — so Cortex never has to guess pixel coordinates visually.
"""

import logging
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

from android_agent.executor.android import AndroidExecutor
from android_agent.graph.state import AgentState

logger = logging.getLogger(__name__)

_DUMP_DEVICE_PATH = "/sdcard/window_dump.xml"


def contextor_node(state: AgentState, executor: AndroidExecutor) -> AgentState:
    """
    Refresh screen context: screenshot + UI accessibility tree + focused app.

    Args:
        state: Current agent state; updated in-place.
        executor: AndroidExecutor used to capture the screenshot.

    Returns:
        Updated state with latest_screenshot_b64, ui_elements, latest_ui_hierarchy,
        and focused_app populated.
    """
    # A — Screenshot
    screenshot_b64 = executor.screenshot("contextor", as_base64=True)
    state.latest_screenshot_b64 = screenshot_b64

    # B — UI accessibility tree
    try:
        state.ui_elements, state.latest_ui_hierarchy = _dump_ui_tree()
    except Exception as exc:
        logger.warning(
            f"UI tree dump failed: {exc} — Cortex will rely on screenshot only"
        )
        state.ui_elements = []
        state.latest_ui_hierarchy = "(UI tree unavailable — using screenshot only)"
        state.ui_tree_available = False

    # Flag empty or very sparse UI trees — Cortex will use vision fallback
    if state.ui_tree_available:  # only check if dump didn't already fail
        clickable_count = sum(1 for e in state.ui_elements if e.get("clickable"))
        if len(state.ui_elements) < 3 or clickable_count < 2:
            state.ui_tree_available = False
            logger.info(
                f"Contextor: UI tree sparse ({len(state.ui_elements)} elements, "
                f"{clickable_count} clickable) — vision fallback enabled"
            )
        else:
            state.ui_tree_available = True

    # C — Focused app
    try:
        state.focused_app = _get_focused_app()
    except Exception as exc:
        logger.warning(f"Focused app query failed: {exc}")
        state.focused_app = None

    logger.debug(
        f"Contextor: {len(state.ui_elements)} elements, " f"focused={state.focused_app}"
    )
    return state


def _dump_ui_tree() -> tuple[list[dict], str]:
    """
    Run uiautomator dump on the device and parse the resulting XML.

    Returns:
        Tuple of (elements list, human-readable hierarchy string).

    Raises:
        RuntimeError: If the dump or pull fails.
    """
    # Dump to device storage
    result = subprocess.run(
        ["adb", "shell", "uiautomator", "dump", _DUMP_DEVICE_PATH],
        capture_output=True,
        text=True,
        timeout=15,
    )
    if result.returncode != 0:
        raise RuntimeError(f"uiautomator dump failed: {result.stderr.strip()}")

    # Pull to a local temp file (works on both macOS and Termux)
    with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as tmp:
        local_path = tmp.name

    pull = subprocess.run(
        ["adb", "pull", _DUMP_DEVICE_PATH, local_path],
        capture_output=True,
        text=True,
        timeout=15,
    )
    if pull.returncode != 0:
        raise RuntimeError(f"adb pull failed: {pull.stderr.strip()}")

    elements = _parse_xml(local_path)
    Path(local_path).unlink(missing_ok=True)

    # Build a compact text representation for the LLM prompt
    lines = []
    for e in elements:
        label = e["text"] or e["content_desc"] or e["resource_id"]
        if label:
            cx, cy = e["center"]["x"], e["center"]["y"]
            if e.get("is_slider"):
                b = e["bounds"]
                lines.append(
                    f"[SLIDER bounds={b['x1']},{b['y1']},{b['x2']},{b['y2']}] {label}"
                    f" — use gesture(x1={b['x1']}, y1={cy}, x2={b['x2']}, y2={cy}, duration_ms=800)"
                )
            else:
                lines.append(
                    f"[{cx},{cy}] {label}" f"{' (clickable)' if e['clickable'] else ''}"
                )
    hierarchy = "\n".join(lines) if lines else "(no labelled elements found)"
    return elements, hierarchy


def _parse_xml(path: str) -> list[dict]:
    """
    Parse a uiautomator XML dump into a list of element dicts.

    Args:
        path: Local filesystem path to the XML file.

    Returns:
        List of dicts with keys: text, content_desc, resource_id,
        bounds, center, clickable.
    """
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        raise RuntimeError(f"XML parse error: {exc}")

    elements = []
    for node in tree.getroot().iter("node"):
        text = node.get("text", "")
        content_desc = node.get("content-desc", "")
        resource_id = node.get("resource-id", "")
        bounds_str = node.get("bounds", "")
        clickable = node.get("clickable", "false") == "true"

        # Skip nodes with no identifying label and no bounds
        if not bounds_str:
            continue
        if not (text or content_desc or resource_id):
            continue

        coords = list(map(int, re.findall(r"\d+", bounds_str)))
        if len(coords) != 4:
            continue

        x1, y1, x2, y2 = coords
        cls = node.get("class", "")
        is_slider = any(s in cls for s in ("SeekBar", "Slider", "RangeBar"))
        elements.append(
            {
                "text": text,
                "content_desc": content_desc,
                "resource_id": resource_id,
                "bounds": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
                "center": {"x": (x1 + x2) // 2, "y": (y1 + y2) // 2},
                "clickable": clickable,
                "is_slider": is_slider,
            }
        )
    return elements


def _get_focused_app() -> str:
    """
    Query which app is currently in the foreground.

    Returns:
        The mCurrentFocus line from dumpsys, truncated to 200 chars.
    """
    result = subprocess.run(
        ["adb", "shell", "dumpsys", "window", "windows"],
        capture_output=True,
        text=True,
        timeout=10,
    )
    for line in result.stdout.split("\n"):
        if "mCurrentFocus" in line:
            return line.strip()[:200]
    return "unknown"
