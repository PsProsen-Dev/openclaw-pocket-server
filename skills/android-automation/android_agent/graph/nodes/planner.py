"""
Planner node — breaks the overall task into 2–5 ordered, verifiable subgoals.
LLM: google/gemini-3-flash-preview .
"""

import json
import logging
from typing import Optional

from android_agent.graph.config import config
from android_agent.graph.state import AgentState, Subgoal
from android_agent.openrouter import text_completion

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """\
You are a mobile automation planner. Given a high-level task to perform on an
Android device, break it into 2-5 ordered, concrete subgoals.

CRITICAL RULES:
- Use the EXACT words from the task. Do NOT rephrase, rename, or substitute
  anything the user said. If the task says "bike ride", the subgoal says
  "bike ride" — not "Uber Moto", not "motorcycle taxi".
- Do NOT assume which app to use unless the task explicitly names one.
- Do NOT add product names, brand names, ride types, or specific options
  that are not in the original task.
- Each subgoal must be a single verifiable UI action or navigation step.
- Subgoals must be ordered — N cannot start before N-1 is complete.
- NEVER create subgoals that read, extract, or report data. The agent taps
  and navigates — the final screenshot IS the output. Mark complete when
  the target screen is reached.

CONTEXT-AWARE GOALS (follow-up tasks):
Sometimes the goal string starts by describing what is ALREADY on screen.
This means the app is already open and showing that state. Examples:

  "Nandini milk is in the Blinkit cart. Go to cart and checkout."
  "Rapido booking screen showing Auto selected. Tap Book Now."
  "Search results for shoes are showing on Amazon. Tap the first result."

When the goal describes a current screen state:
  - Do NOT create a subgoal to open the app. It is already open.
  - Do NOT create subgoals for steps that are already done (described in the context).
  - Start your plan from the CURRENT state described, with the NEXT action needed.
  - Your first subgoal should be the action on the current screen.

Example:
  Goal: "Rapido Auto ride is selected from K3 Mantion to Nexus Mall. Tap Book Now."
  CORRECT plan:
  [
    {"id":"sg1","description":"Tap the Book Now button to confirm the ride"}
  ]
  WRONG plan:
  [
    {"id":"sg1","description":"Open the Rapido app"},
    {"id":"sg2","description":"Set pickup to K3 Mantion"},
    {"id":"sg3","description":"Tap Book Now"}
  ]
  The wrong plan redoes everything from scratch, destroying the current screen.

How to detect context-aware goals:
- The goal mentions something "is already", "is showing", "is selected", "is in the cart"
- The goal describes a screen state before giving the action
- The first sentence is a statement (not an instruction), followed by an action

When in doubt, look at the goal structure:
  "[Description of current state]. [Action to take]." → context-aware, start from the action
  "[Action to take]" → fresh task, plan from the beginning

Return ONLY a JSON array, no other text:
[
  {"id": "sg1", "description": "..."},
  {"id": "sg2", "description": "..."}
]"""


def planner_node(state: AgentState) -> AgentState:
    """
    Create or revise the subgoal plan based on the current task and any failures.

    Args:
        state: Current agent state; reads initial_goal and any failed subgoals.

    Returns:
        Updated state with a fresh subgoal_plan (all statuses reset to pending).
    """
    failed = [sg for sg in state.subgoal_plan if sg.status == "failed"]

    user_text = f"Task: {state.initial_goal}"
    if failed:
        user_text += (
            f"\n\nPrevious plan failed at subgoal: '{failed[0].description}'"
            f"\nFailure reason: {failed[0].failure_reason or 'unknown'}"
            "\n\nCreate a new plan that avoids this failure with a different approach."
        )

    subgoals = _call_with_retry(user_text)
    if subgoals is None:
        # Fallback: single subgoal = the original task
        subgoals = [{"id": "sg1", "description": state.initial_goal}]

    state.subgoal_plan = [
        Subgoal(id=sg["id"], description=sg["description"]) for sg in subgoals
    ]
    thought = f"[planner] Plan with {len(state.subgoal_plan)} subgoals: " + " → ".join(
        sg.description for sg in state.subgoal_plan
    )
    state.agents_thoughts.append(thought)
    logger.info(thought)
    return state


def _call_with_retry(user_text: str, retries: int = 2) -> Optional[list]:
    """
    Call the planner LLM and parse its JSON response, with retries on parse failure.

    Args:
        user_text: Prompt for the model.
        retries: How many times to retry on bad JSON.

    Returns:
        List of {id, description} dicts, or None on total failure.
    """
    for attempt in range(retries + 1):
        try:
            raw = text_completion(
                model=config.PLANNER_MODEL,
                system_prompt=_SYSTEM_PROMPT,
                user_text=user_text,
                max_tokens=512,
            )
            stripped = raw.strip()
            if stripped.startswith("```"):
                lines = stripped.split("\n")
                inner = lines[1:-1] if lines[-1].strip() == "```" else lines[1:]
                stripped = "\n".join(inner).strip()
            return json.loads(stripped)
        except Exception as exc:
            logger.warning(f"Planner attempt {attempt + 1} failed: {exc}")
    return None
