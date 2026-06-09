# Unattended Execution System

## Overview

This system allows an AI agent to operate autonomously during work hours. It's controlled by an environment variable and runs on a cron schedule.

## Quick Start

### Enable Unattended Execution
```bash
echo 'UNATTENDED_EXECUTION=true' > tools/unattended/UNATTENDED.env
```

### Disable Unattended Execution
```bash
echo 'UNATTENDED_EXECUTION=false' > tools/unattended/UNATTENDED.env
```

### Check Status
```bash
cat tools/unattended/UNATTENDED.env
python3 tools/unattended/turn_runner.py --status
```

### Add a Cron Job (every 15 minutes)
```bash
crontab -e
# Add this line (adjust paths as needed):
*/15 * * * * /path/to/tools/unattended/scheduler.sh >> /path/to/tools/unattended/logs/scheduler.log 2>&1
```

### View Logs
```bash
tail -f tools/unattended/logs/scheduler.log
cat tools/unattended/activity_log.md
```

## How It Works

```
Every 15 minutes:
  ┌─────────────────────────────────────────────┐
  │ scheduler.sh                                │
  │  1. Check UNATTENDED.env                    │
  │  2. If true → check GPU utilization         │
  │  3. If GPU idle → check lock                │
  │  4. If no lock → run turn                   │
  │  5. Lock until turn completes               │
  │  6. Update state.json                       │
  └─────────────────────────────────────────────┘
           ↓
  ┌─────────────────────────────────────────────┐
  │ opencode run (with seed prompt)             │
  │  AI agent executes:                         │
  │  1. Read state.json (restore context)       │
  │  2. Read guardrails.md                      │
  │  3. Read directives.md                      │
  │  4. Execute meaningful work                 │
  │  5. Update activity_log.md                  │
  │  6. Update state.json (save handoff)        │
  │  7. Send turn report email                  │
  └─────────────────────────────────────────────┘
```

## File Structure

```
tools/unattended/
├── UNATTENDED.env          # Master on/off switch
├── scheduler.sh            # Cron-compatible scheduler with GPU guard
├── turn_runner.py          # Turn state management
├── seed_prompt.txt         # System prompt for each turn
├── state.json              # Execution state, progress tracking, handoff context
├── directives.md           # Active and completed tasks
├── activity_log.md         # Timestamped activity log
├── approval_queue.md       # Actions needing human approval
├── guardrails.md           # Safety rules and constraints
├── templates/
│   └── daily_report.html   # HTML email template for reports
└── logs/
    ├── scheduler.log       # Scheduler execution log
    └── research/           # Research findings directory
```

## Safety

All operations are bounded by guardrails.md. Key rules:
- Always identify as AI in external communications
- Never expose secrets, API keys, or credentials
- Never impersonate a human
- No financial transactions
- No destructive operations outside approved directories
- Actions requiring approval go in approval_queue.md
- Binary fetch protection: never fetch URLs that return binary content (PDFs, images, etc.)

## Resource Protection

The scheduler protects GPU resources on the inference server:

- **GPU utilization check:** Before each turn, the scheduler checks GPU utilization via SSH. If any GPU exceeds a configurable threshold (default 20%), the turn is skipped. This prevents collision with interactive sessions.
- **Session rotation:** After 5 turns, the session is rotated to avoid context window limits and compaction corruption.
- **Lock file:** Prevents overlapping turns from running simultaneously.

Configure threshold:
```bash
export GPU_THRESHOLD=20    # Skip turn if any GPU > 20% (default)
```

## Communication

- **Turn reports** sent to the user after every turn
- **Activity log** updated after every action
- **State file** tracks progress and inference usage
- **Outbound emails** are logged with timestamps

## Session Rotation

Sessions rotate every 5 turns to avoid context window limits. The `handoff_context` in `state.json` carries working memory between sessions:

```json
{
  "handoff_context": {
    "current_phase": "What phase/task you were working on",
    "what_was_built": ["files created or modified"],
    "key_findings": ["important results and conclusions"],
    "next_steps": "What to work on next",
    "decisions_pending": [],
    "blockers": []
  }
}
```

This ensures the next session picks up exactly where the previous one left off, even without conversational context.

## Tracking Inference Costs

The system tracks:
- Total turns executed
- API calls made
- Tokens estimated (rough)
- Time spent per turn

Review this data after the experimental period to set runtime budgets.
