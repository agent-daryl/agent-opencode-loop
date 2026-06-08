#!/usr/bin/env python3
"""
Response dedup tracker for unattended email operations.

Prevents sending duplicate responses to the same email thread by tracking
responded message IDs and subjects in state.json.

Usage as library:
    from tools.unattended.response_dedup import DedupTracker

    tracker = DedupTracker('/path/to/state.json')
    if tracker.already_responded(message_id, subject):
        print("Skip - already responded")
    else:
        send_reply(...)
        tracker.record_response(message_id, subject, timestamp)
    tracker.save_to_state(state)
"""

import json
import time
from datetime import datetime, timezone, timedelta
from typing import Optional


MTD_OFFSET = timedelta(hours=-6)


def _now_mdt() -> str:
    """Return current time in MDT/MTS as ISO string."""
    return (datetime.now(timezone.utc) + MTD_OFFSET).isoformat()


class DedupTracker:
    """Track responded email threads to prevent duplicate responses."""

    def __init__(self, state_path: str):
        self.state_path = state_path
        self.responded = self._load()

    def _load(self) -> list:
        """Load responded_threads from state.json."""
        try:
            with open(self.state_path, 'r') as f:
                state = json.load(f)
            return state.get('responded_threads', [])
        except (FileNotFoundError, json.JSONDecodeError):
            return []

    def already_responded(self, message_id: str = '', subject: str = '') -> bool:
        """Check if we've already responded to this message or subject."""
        for entry in self.responded:
            if message_id and entry.get('message_id') == message_id:
                return True
            if subject and entry.get('subject', '').lower() == subject.lower():
                return True
        return False

    def record_response(self, message_id: str, subject: str, timestamp: Optional[str] = None):
        """Record that we responded to a thread."""
        self.responded.append({
            'message_id': message_id,
            'subject': subject,
            'responded_at': timestamp or _now_mdt(),
        })
        # Keep only last 50 entries to prevent unbounded growth
        if len(self.responded) > 50:
            self.responded = self.responded[-50:]

    def get_pending_subjects(self, inbox_subjects: list) -> list:
        """Return subjects from inbox that we haven't responded to yet."""
        responded_subjects = {e.get('subject', '').lower() for e in self.responded}
        return [s for s in inbox_subjects if s.lower() not in responded_subjects]

    def save_to_state(self, state: dict):
        """Persist responded_threads back into state.json."""
        state['responded_threads'] = self.responded
        with open(self.state_path, 'w') as f:
            json.dump(state, f, indent=2)

    def summary(self) -> str:
        """Return a short summary of tracking status."""
        return f"Tracking {len(self.responded)} responded threads"


if __name__ == '__main__':
    import sys
    state_path = sys.argv[1] if len(sys.argv) > 1 else 'tools/unattended/state.json'
    tracker = DedupTracker(state_path)

    # CLI: check if a subject was already responded to
    if len(sys.argv) > 2:
        subject = ' '.join(sys.argv[2:])
        result = tracker.already_responded(subject=subject)
        print(f"Already responded to '{subject}': {result}")
        print(tracker.summary())
    else:
        print(tracker.summary())
        if tracker.responded:
            for e in tracker.responded:
                print(f"  [{e['responded_at']}] {e['subject']}")
