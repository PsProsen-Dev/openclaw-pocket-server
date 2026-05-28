"""
Executor node — translates Cortex tool calls into ADB actions via android.py.
android.py is NEVER modified; this wrapper adapts its interface.
"""

import logging
import os
import time

from android_agent.executor.android import AndroidExecutor
from android_agent.graph.state import AgentState

logger = logging.getLogger(__name__)

# Settle time after every action (seconds) — gives UI time to respond
_POST_ACTION_DELAY = 2.0


class ExecutorNode:
    """Wraps AndroidExecutor and dispatches Cortex tool decisions."""

    def __init__(self, executor: AndroidExecutor, device_id: str = None):
        """
        Args:
            executor: AndroidExecutor instance (android.py).
            device_id: Optional ADB serial; sets ANDROID_SERIAL env var so
                       android.py's subprocess calls target the right device
                       without modifying android.py.
        """
        self.executor = executor
        if device_id:
            os.environ["ANDROID_SERIAL"] = device_id

    def execute(self, state: AgentState) -> AgentState:
        """
        Run the tool chosen by Cortex against the Android device.

        Args:
            state: Must have structured_decision populated by Cortex.

        Returns:
            Updated state with action_history appended and step_count incremented.
        """
        decision = state.structured_decision
        if not decision:
            logger.warning("Executor called with no structured_decision")
            return state

        tool = decision.get("tool", "wait")
        args = decision.get("args", {})
        reason = decision.get("reason", "")

        self._dispatch(tool, args, reason, state)

        state.step_count += 1
        time.sleep(_POST_ACTION_DELAY)
        return state

    def _dispatch(self, tool: str, args: dict, reason: str, state: AgentState) -> None:
        """
        Route a tool name to the correct android.py call.

        Args:
            tool: Tool name from Cortex decision.
            args: Tool arguments.
            reason: Human-readable reason (used as observation in android.py calls).
            state: Agent state for recording history and updating subgoal status.
        """
        if tool == "tap":
            x, y = int(args.get("x", 0)), int(args.get("y", 0))
            # uiautomator coordinates are real screen pixels — disable scaling.
            # android.py multiplies by image_scale_factor (set from screenshot
            # compression), which is wrong when coords come from the UI tree.
            self.executor.image_scale_factor = 1.0
            self.executor.click_at_a_point(x, y, reason)
            state.action_history.append(f"TAP ({x}, {y}) — {reason}")

        elif tool == "type_text":
            text = args.get("text", "")
            press_enter = args.get("press_enter", False)
            self.executor.type_text(text, reason, press_enter=press_enter)
            state.action_history.append(f"TYPE {text!r} (enter={press_enter})")
            # Extra delay after typing — lets search suggestions / autocomplete load
            # from server before the Summarizer takes a screenshot.
            # Combined with _POST_ACTION_DELAY (2s), total wait after typing = 4s.
            time.sleep(2.0)

        elif tool == "clear_field":
            self.executor.clear_focused_field(reason)
            state.action_history.append("CLEAR FIELD")

        elif tool == "long_press":
            x, y = int(args.get("x", 0)), int(args.get("y", 0))
            duration = int(args.get("duration_ms", 1000))
            self.executor.image_scale_factor = 1.0
            self.executor.long_press_at_a_point(x, y, reason, duration=duration)
            state.action_history.append(f"LONG_PRESS ({x}, {y}) {duration}ms — {reason}")

        elif tool == "gesture":
            x1 = int(args.get("x1", 0))
            y1 = int(args.get("y1", 0))
            x2 = int(args.get("x2", 0))
            y2 = int(args.get("y2", 0))
            duration_ms = int(args.get("duration_ms", 300))
            self.executor.gesture(x1, y1, x2, y2, duration_ms)
            state.action_history.append(
                f"GESTURE ({x1},{y1})->({x2},{y2}) {duration_ms}ms"
            )

        elif tool == "press_key":
            key = args.get("key", "back")
            if key == "back":
                self.executor.navigate_back(reason)
            elif key == "home":
                self.executor.minimize_app(reason)
            elif key == "enter":
                self.executor.press_key(["66"], reason)
            elif key == "recent_apps":
                self.executor.press_key(["187"], reason)
            else:
                logger.warning(f"Unknown key: {key!r}")
            state.action_history.append(f"PRESS {key}")

        elif tool == "wait":
            seconds = min(float(args.get("seconds", 1.5)), 5.0)
            time.sleep(seconds)
            state.action_history.append(f"WAIT {seconds}s")

        elif tool == "mark_subgoal_complete":
            reason_text = args.get("reason", "subgoal achieved")
            for sg in state.subgoal_plan:
                if sg.status == "running":
                    sg.status = "complete"
                    state.action_history.append(f"✅ COMPLETE: {sg.description}")
                    logger.info(f"Subgoal complete: {sg.description}")
                    break

        elif tool == "mark_subgoal_failed":
            reason_text = args.get("reason", "unknown failure")
            for sg in state.subgoal_plan:
                if sg.status == "running":
                    sg.status = "failed"
                    sg.failure_reason = reason_text
                    state.action_history.append(f"❌ FAILED: {sg.description}")
                    logger.warning(f"Subgoal failed: {sg.description} — {reason_text}")
                    break

        else:
            logger.warning(f"Unknown tool: {tool!r}")
            state.action_history.append(f"UNKNOWN TOOL: {tool}")
