"""
Shared state object passed between every node in the graph.
"""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Subgoal:
    """One verifiable step in the overall task plan."""

    id: str
    description: str
    status: str = "pending"  # pending | running | complete | failed
    failure_reason: Optional[str] = None


@dataclass
class AgentState:
    """
    Mutable state bag threaded through every node each iteration.

    Fields are grouped by concern:
    - Task / plan
    - Current screen context (refreshed by Contextor every loop)
    - Cortex decision (what to do next)
    - Memory / audit trail
    - Loop control
    """

    # --- Task ---
    initial_goal: str
    subgoal_plan: list[Subgoal] = field(default_factory=list)

    # --- Screen context (refreshed every loop by Contextor) ---
    latest_screenshot_b64: Optional[str] = None
    latest_ui_hierarchy: Optional[str] = None  # human-readable element list
    ui_elements: list[dict] = field(default_factory=list)
    focused_app: Optional[str] = None
    ui_tree_available: bool = True  # False when uiautomator dump returned empty/sparse results

    # --- Cortex output ---
    structured_decision: Optional[dict] = None  # {tool, args, reason, thought}

    # --- Memory ---
    action_history: list[str] = field(default_factory=list)
    agents_thoughts: list[str] = field(default_factory=list)
    scratchpad: dict = field(default_factory=dict)  # arbitrary per-run data

    # --- Control ---
    step_count: int = 0
    max_steps: int = 25
    task_complete: bool = False
    task_failed: bool = False
    failure_reason: Optional[str] = None
