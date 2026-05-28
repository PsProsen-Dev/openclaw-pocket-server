#!/usr/bin/env node
// OpenClaw assistant-sdk runtime entry point (AnyClaw v514)
import { createAgentSession } from '../agent-core/src/index.js';
const session = await createAgentSession({ provider: process.env.OCA_LLM_PROVIDER || 'openai' });
console.log('[openclaw-assistant] Agent session ready. Provider:', process.env.OCA_LLM_PROVIDER || 'openai');
export { session };
