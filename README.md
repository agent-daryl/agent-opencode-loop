# Unattended Execution System

## Overview

This system allows agent-daryl to operate autonomously during Daryl's work hours. It's controlled by an environment variable and runs on a cron schedule.

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

### Add a Cron Job (every 20 minutes)
```bash
crontab -e
# Add this line:
*/20 * * * * /home/daryl/Documents/ai_workloads/tools/unattended/scheduler.sh >> /home/daryl/Documents/ai_workloads/tools/unattended/logs/scheduler.log 2>&1
```

### View Logs
```bash
tail -f tools/unattended/logs/scheduler.log
cat tools/unattended/activity_log.md
```

## How It Works

```
Every 10 minutes:
  ┌─────────────────────────────────────────────┐
  │ scheduler.sh                                │
  │  1. Check UNATTENDED.env                    │
  │  2. If true → check lock                    │
  │  3. If no lock → run turn                   │
  │  4. Lock until turn completes               │
  │  5. Update state.json                       │
  └─────────────────────────────────────────────┘
           ↓
  ┌─────────────────────────────────────────────┐
  │ opencode -p seed_prompt.txt                 │
  │  AI agent executes:                         │
  │  1. Read state.json                         │
  │  2. Read guardrails.md                      │
  │  3. Read directives.md                      │
  │  4. Execute meaningful work                 │
  │  5. Update activity_log.md                  │
  │  6. Update state.json                       │
  │  7. Send daily report (last turn of day)    │
  └─────────────────────────────────────────────┘
```

## File Structure

```
tools/unattended/
├── UNATTENDED.env          # Master on/off switch
├── scheduler.sh            # Cron-compatible scheduler
├── turn_runner.py          # Turn state management
├── seed_prompt.txt         # System prompt for each turn
├── state.json              # Execution state, progress tracking
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

## Resource Protection

The scheduler protects AI-box GPU resources:

- **GPU utilization check:** Before each turn, the scheduler SSHes to the AI-box and checks `nvidia-smi`. If any GPU exceeds 20% utilization, the turn is skipped. This prevents collision with your interactive sessions or other turns.
- **No time cap:** Turns can run as long as needed. Cron runs every 20 minutes, so a long-running turn simply occupies the slot until it finishes.
- **Lock file:** Prevents overlapping turns from running simultaneously.

Configure threshold:
```bash
export GPU_THRESHOLD=20    # Skip turn if any GPU > 20% (default)
```

## Communication

- **Daily reports** sent to daryl.allen.jr@gmail.com
- **Activity log** updated after every action
- **State file** tracks progress and inference usage
- **Outbound emails** are logged with timestamps

## Tracking Inference Costs

The system tracks:
- Total turns executed
- API calls made
- Tokens estimated (rough)
- Time spent per turn

Review this data after the experimental period to set runtime budgets.
