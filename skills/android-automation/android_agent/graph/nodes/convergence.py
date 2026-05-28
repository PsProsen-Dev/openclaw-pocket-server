"""
Convergence node — pure Python routing logic, no LLM.

Returns one of three strings that the runner uses to decide the next step:
  "end"      — task is complete or permanently failed
  "replan"   — a subgoal failed; the planner should try again
  "continue" — keep running the contextor → cortex → executor → summarizer loop
"""

import logging

from android_agent.graph.state import AgentState

logger = logging.getLogger(__name__)

_MAX_REPLAN_ATTEMPTS = 2


def convergence_node(state: AgentState) -> str:
    """
    Determine what the runner should do next.

    Checks (in priority order):
      1. Step limit exceeded → end (failed)
      2. task_complete or task_failed flags → end
      3. Any failed subgoal → replan (up to _MAX_REPLAN_ATTEMPTS times)
      4. All subgoals complete → end (success)
      5. Otherwise → continue

    Args:
        state: Current agent state.

    Returns:
        "end", "replan", or "continue".
    """
    # 1 — Hard step cap
    if state.step_count >= state.max_steps:
        state.task_failed = True
        state.failure_reason = f"Exceeded max_steps ({state.max_steps})"
        logger.warning(state.failure_reason)
        return "end"

    # 2 — Explicit terminal flags
    if state.task_complete:
        return "end"
    if state.task_failed:
        return "end"

    # 3 — Failed subgoal → maybe replan
    failed = [sg for sg in state.subgoal_plan if sg.status == "failed"]
    if failed:
        replan_count = sum(1 for t in state.agents_thoughts if "[replan]" in t.lower())
        if replan_count >= _MAX_REPLAN_ATTEMPTS:
            state.task_failed = True
            state.failure_reason = (
                f"Subgoal failed after {_MAX_REPLAN_ATTEMPTS} replan attempts: "
                f"{failed[0].failure_reason or failed[0].description}"
            )
            logger.error(state.failure_reason)
            return "end"
        state.agents_thoughts.append(
            f"[replan] Subgoal failed, requesting replan #{replan_count + 1}"
        )
        logger.info(f"Triggering replan #{replan_count + 1}")
        return "replan"

    # 4 — All complete
    if state.subgoal_plan and all(sg.status == "complete" for sg in state.subgoal_plan):
        state.task_complete = True
        return "end"

    # 5 — Keep going
    return "continue"
