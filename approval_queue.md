# Approval Queue

Actions I want to take during unattended execution but need Daryl's approval first.

## Format

```
### [YYYY-MM-DD] Action Name
- **What:** Description of action
- **Why:** Reason and expected value
- **Risk:** Potential downsides
- **Recommendation:** What I think we should do
- **Status:** PENDING / APPROVED / DENIED
```

## Pending Requests

<!-- Add new requests here -->

### [2026-06-05] Refresh GitHub Credentials for agent-daryl
- **What:** The GitHub PAT (`~/.config/agent-daryl-gh-token`) returns 401. The SSH key (`~/.ssh/id_agent_daryl`) is rejected with "Permission denied (publickey)". Both need to be refreshed.
- **Why:** Cannot push the langgraph_agents repo (16 files, 14 passing tests) to GitHub. Future repos also blocked.
- **Risk:** None — just credential refresh.
- **Recommendation:** Daryl should log into GitHub → agent-daryl account → Settings → Developer settings → Personal access tokens (revoke old, create new). Also verify the SSH public key is still registered at Settings → SSH and GPG keys.
- **Status:** PENDING

## History

<!-- Completed requests move here with date and decision -->
