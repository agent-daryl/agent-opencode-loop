#!/usr/bin/env python3
"""
Unattended Execution — Turn Runner

Reads state, executes a turn, updates state and logs, optionally sends report.

Usage:
    python3 turn_runner.py              # Run one turn
    python3 turn_runner.py --report     # Generate and send daily report
    python3 turn_runner.py --status     # Show current state
"""

import json
import sys
import os
import argparse
from datetime import datetime, timezone, timedelta

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(BASE_DIR, "state.json")
ACTIVITY_LOG = os.path.join(BASE_DIR, "activity_log.md")
DIRECTIVES_FILE = os.path.join(BASE_DIR, "directives.md")
REPORT_TEMPLATE = os.path.join(BASE_DIR, "templates", "daily_report.html")
LOG_DIR = os.path.join(BASE_DIR, "logs")


def load_state():
    """Load execution state from JSON."""
    try:
        with open(STATE_FILE, "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return {
            "version": 1,
            "created": datetime.now(timezone.utc).isoformat(),
            "last_run": None,
            "total_turns": 0,
            "total_emails_sent": 0,
            "active_directive": None,
            "current_task_progress": None,
            "last_activity_summary": None,
            "inference_tracking": {
                "total_tokens_estimated": 0,
                "total_api_calls": 0,
                "sessions": [],
            },
            "emails_sent": [],
            "notes": "",
        }


def save_state(state):
    """Save execution state to JSON."""
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def log_activity(action, description, details=None):
    """Append an entry to the activity log."""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"\n[{now}] [{action}] {description}\n"
    if details:
        for line in details:
            entry += f"  - {line}\n"

    with open(ACTIVITY_LOG, "r") as f:
        content = f.read()

    # Insert after the "## Log Entries" header
    marker = "## Log Entries\n"
    insert_point = content.find(marker)
    if insert_point != -1:
        # Remove the "<!-- Most recent entries at the top -->" comment
        comment = "<!-- Most recent entries at the top -->\n"
        content = content.replace(comment, "")
        new_content = (
            content[: insert_point + len(marker)]
            + entry
            + content[insert_point + len(marker) :]
        )
    else:
        new_content = content + entry

    with open(ACTIVITY_LOG, "w") as f:
        f.write(new_content)


def get_directives():
    """Read active directives from directives.md."""
    try:
        with open(DIRECTIVES_FILE, "r") as f:
            content = f.read()
        active_section = content.split("## Active Directives")[1].split("## Completed Directives")[0]
        directives = []
        for line in active_section.strip().split("\n"):
            line = line.strip()
            if line.startswith("- [ ]"):
                directives.append(line.replace("- [ ]", "").strip())
        return directives
    except Exception:
        return []


def generate_daily_report(state):
    """Generate an HTML daily report from state and activity log."""
    # Read template
    try:
        with open(REPORT_TEMPLATE, "r") as f:
            template = f.read()
    except FileNotFoundError:
        return None

    # Read activity log for recent entries
    try:
        with open(ACTIVITY_LOG, "r") as f:
            activity_content = f.read()
    except FileNotFoundError:
        activity_content = ""

    # Parse recent activities
    activities = []
    email_items = []
    tasks_done = 0

    for line in activity_content.split("\n"):
        if "[WORK]" in line:
            tasks_done += 1
            activities.append(f"<li>{line.strip()}</li>")
        elif "[EMAIL]" in line:
            email_items.append(f"<li>{line.strip()}</li>")

    # Build summary
    summary = state.get("last_activity_summary", "No summary available for this period.")
    next_steps = state.get("current_task_progress", "Continuing with active directives.")

    # Build activity items
    activity_items = "\n".join(activities[-10:]) if activities else "<li>No work completed this period.</li>"
    email_log_items = "\n".join(email_items) if email_items else "<li>No outbound emails sent this period.</li>"

    # Fill template
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    report = template.format(
        REPORT_DATE=now,
        TURNS=state.get("total_turns", 0),
        TASKS_DONE=tasks_done,
        EMAILS_SENT=state.get("total_emails_sent", 0),
        SUMMARY=summary,
        ACTIVITY_ITEMS=activity_items,
        NEXT_STEPS=next_steps,
        EMAIL_LOG_ITEMS=email_log_items,
    )

    return report


def send_daily_report(report_html):
    """Send the daily report email to Daryl."""
    sys.path.insert(0, os.path.join(BASE_DIR, "..", "src"))
    try:
        from send_html_email import send_html_email
    except ImportError:
        print("Error: send_html_email module not found.", file=sys.stderr)
        return False

    now = datetime.now().strftime("%Y-%m-%d")
    subject = f"[agent-daryl] Unattended Execution Report — {now}"
    success = send_html_email(
        to_address="daryl.allen.jr@gmail.com",
        subject=subject,
        html_content=report_html,
    )

    if success:
        log_activity(
            "EMAIL",
            "Daily report sent to daryl.allen.jr@gmail.com",
            [f"Subject: {subject}", f"Template: daily_report.html"],
        )
        return True
    return False


def show_status():
    """Display current state summary."""
    state = load_state()
    print(f"Unattended Execution State")
    print(f"{'=' * 40}")
    print(f"  Created:        {state.get('created', 'N/A')}")
    print(f"  Last run:       {state.get('last_run', 'Never')}")
    print(f"  Total turns:    {state.get('total_turns', 0)}")
    print(f"  Emails sent:    {state.get('total_emails_sent', 0)}")
    print(f"  Active task:    {state.get('active_directive', 'None')}")
    print(f"  Progress:       {state.get('current_task_progress', 'N/A')}")
    print()

    directives = get_directives()
    print(f"  Active directives: {len(directives)}")
    for d in directives:
        print(f"    • {d}")


def run_turn():
    """Execute one turn of unattended work."""
    state = load_state()

    log_activity(
        "TURN",
        f"Turn {state.get('total_turns', 0) + 1} started",
        [f"Active directive: {state.get('active_directive', 'None')}"],
    )

    directives = get_directives()
    if not directives:
        log_activity("INFO", "No active directives. Waiting for new tasks.")
        return

    # Update state with current directive
    state["active_directive"] = directives[0] if directives else None
    state["last_run"] = datetime.now().isoformat()
    save_state(state)

    # The actual work is done by the AI agent during the opencode session.
    # This script handles state management, logging, and reporting.
    log_activity(
        "INFO",
        "Turn execution delegated to AI agent via seed prompt.",
        [f"Directive: {directives[0] if directives else 'None'}"],
    )


def main():
    parser = argparse.ArgumentParser(description="Unattended Execution Turn Runner")
    parser.add_argument("--report", action="store_true", help="Generate and send daily report")
    parser.add_argument("--status", action="store_true", help="Show current state")
    args = parser.parse_args()

    if args.status:
        show_status()
    elif args.report:
        report = generate_daily_report(load_state())
        if report:
            if send_daily_report(report):
                print("Daily report sent successfully.")
            else:
                print("Failed to send daily report.", file=sys.stderr)
                sys.exit(1)
        else:
            print("Failed to generate report.", file=sys.stderr)
            sys.exit(1)
    else:
        run_turn()
        print("Turn started. AI agent will execute via seed prompt.")


if __name__ == "__main__":
    main()
