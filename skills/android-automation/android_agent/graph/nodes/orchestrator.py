"""
Orchestrator node — pure Python, no LLM.
Advances the subgoal plan: activates the next pending subgoal, or marks the
task complete if all subgoals are done.
"""

import logging

from android_agent.graph.state import AgentState

logger = logging.getLogger(__name__)


def orchestrator_node(state: AgentState) -> AgentState:
    """
    Activate the next pending subgoal or mark the task complete.

    - If a subgoal is already "running", do nothing (it is still in progress).
    - If a subgoal is "pending", set it to "running" and reset the failure counter.
    - If all subgoals are complete, set state.task_complete = True.

    Args:
        state: Current agent state.

    Returns:
        Updated state.
    """
    for sg in state.subgoal_plan:
        if sg.status == "running":
            # Already active — let it continue
            return state
        if sg.status == "pending":
            sg.status = "running"
            state.scratchpad["current_subgoal_failures"] = 0
            thought = f"[orchestrator] Starting subgoal {sg.id}: {sg.description}"
            state.agents_thoughts.append(thought)
            logger.info(thought)
            return state

    # All subgoals are either complete or failed; if all complete → done
    all_complete = all(sg.status == "complete" for sg in state.subgoal_plan)
    if all_complete:
        state.task_complete = True
        state.agents_thoughts.append("[orchestrator] All subgoals complete — task done")

    return state
