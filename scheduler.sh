#!/bin/bash
#
# Unattended Execution Scheduler
# Checks UNATTENDED_EXECUTION env var every 15 minutes.
# If enabled, runs opencode in a persistent session (with rotation after MAX_SESSION_TURNS).
#
# Cron entry (add with `crontab -e`):
# */15 * * * * /home/daryl/Documents/ai_workloads/tools/unattended/scheduler.sh >> /home/daryl/Documents/ai_workloads/tools/unattended/logs/scheduler.log 2>&1
#
# Manual run:
#   bash /home/daryl/Documents/ai_workloads/tools/unattended/scheduler.sh
#

set -euo pipefail

WORKSPACE="/home/daryl/Documents/ai_workloads"
OPENCODE_BIN="/home/daryl/.opencode/bin/opencode"
ENV_FILE="${WORKSPACE}/tools/unattended/UNATTENDED.env"
STATE_FILE="${WORKSPACE}/tools/unattended/state.json"
LOG_FILE="${WORKSPACE}/tools/unattended/logs/scheduler.log"
SEED_PROMPT="${WORKSPACE}/tools/unattended/seed_prompt.txt"
LOCK_FILE="${WORKSPACE}/tools/unattended/.scheduler.lock"

# Maximum turns per session before rotation
# Set lower to avoid context bloat and corruption bugs
MAX_SESSION_TURNS=5

# Check if enabled
check_enabled() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] ENV_FILE not found: $ENV_FILE" >> "$LOG_FILE"
        return 1
    fi

    local value
    value=$(grep '^UNATTENDED_EXECUTION=' "$ENV_FILE" | cut -d'=' -f2 | tr -d '[:space:]')

    if [[ "$value" != "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Unattended execution disabled (UNATTENDED_EXECUTION=$value). Exiting." >> "$LOG_FILE"
        return 1
    fi

    return 0
}

# Check GPU utilization on AI-box
# If utilization is above threshold, skip the turn
check_gpu_utilization() {
    local threshold=${GPU_THRESHOLD:-20}
    local ai_box_ssh="ssh -i ~/.ssh/id_opencode opencode-agent@172.16.0.20 -o StrictHostKeyChecking=no -o ConnectTimeout=10"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Checking GPU utilization on AI-box..." >> "$LOG_FILE"

    local nvidia_output
    nvidia_output=$($ai_box_ssh "nvidia-smi" 2>/dev/null) || {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Could not reach AI-box via SSH. Skipping turn." >> "$LOG_FILE"
        return 1
    }

    local busy=0
    local gpu_utils=""
    while IFS= read -r line; do
        if echo "$line" | grep -q "P[0-9]" && echo "$line" | grep -q "Default"; then
            local util
            util=$(echo "$line" | grep -oP '\d+%' | tail -1 | grep -oP '\d+')
            if [[ -n "$util" ]]; then
                if [[ -n "$gpu_utils" ]]; then
                    gpu_utils="$gpu_utils, ${util}%"
                else
                    gpu_utils="${util}%"
                fi
                if (( util > threshold )); then
                    busy=1
                fi
            fi
        fi
    done <<< "$nvidia_output"

    if [[ $busy -eq 1 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] GPU busy (utilization > ${threshold}%): $gpu_utils. Skipping turn." >> "$LOG_FILE"
        return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] GPU idle (utilization <= ${threshold}%): $gpu_utils. Proceeding." >> "$LOG_FILE"
    return 0
}

# Check if another instance is running (prevent overlapping turns)
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "unknown")
        if kill -0 "$lock_pid" 2>/dev/null; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Another turn is running (PID $lock_pid). Skipping." >> "$LOG_FILE"
            return 1
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Stale lock found (PID $lock_pid). Removing." >> "$LOG_FILE"
            rm -f "$LOCK_FILE"
        fi
    fi
    return 0
}

# Set lock
set_lock() {
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
}

# Read seed prompt
read_seed_prompt() {
    if [[ ! -f "$SEED_PROMPT" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] SEED_PROMPT not found: $SEED_PROMPT" >> "$LOG_FILE"
        return 1
    fi
    cat "$SEED_PROMPT"
}

# Get current session info from state.json
# Returns: session_id session_turns
get_session_info() {
    python3 -c "
import json, sys
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    session_id = state.get('unattended_session', {}).get('session_id', '')
    session_turns = state.get('unattended_session', {}).get('session_turns', 0)
    print(f'{session_id} {session_turns}')
except Exception as e:
    print(f' 0')
" 2>/dev/null || echo " 0"
}

# Update session info in state.json
update_session_info() {
    local new_session_id="$1"
    local new_session_turns="$2"
    local new_global_turn="$3"

    python3 -c "
import json, sys
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    if 'unattended_session' not in state:
        state['unattended_session'] = {}
    state['unattended_session']['session_id'] = '$new_session_id'
    state['unattended_session']['session_turns'] = $new_session_turns
    state['unattended_session']['global_turn'] = $new_global_turn
    state['last_run'] = '$(date -u '+%Y-%m-%dT%H:%M:%S+0000')'
    state['total_turns'] = state.get('total_turns', 0) + 1
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f'Warning: Could not update state: {e}', file=sys.stderr)
" 2>/dev/null || true
}

# Extract session ID from opencode JSON output
# Every JSON event line contains a sessionID field — extract from first valid line
extract_session_id() {
    local output_file="$1"
    python3 -c "
import json, sys
try:
    with open('$output_file', 'r') as f:
        content = f.read()
    for line in content.split('\n'):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
            sid = event.get('sessionID', '') or event.get('session', {}).get('id', '')
            if sid and sid.startswith('ses_'):
                print(sid)
                sys.exit(0)
        except json.JSONDecodeError:
            continue
    print('')
except Exception as e:
    print('')
" 2>/dev/null || echo ""
}

# Run a turn via opencode
run_turn() {
    local prompt
    prompt=$(read_seed_prompt)

    if [[ -z "$prompt" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Empty seed prompt. Skipping turn." >> "$LOG_FILE"
        return 1
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Starting unattended turn (PID $$)." >> "$LOG_FILE"

    # Get current session info
    local session_info
    session_info=$(get_session_info)
    local current_session_id
    current_session_id=$(echo "$session_info" | cut -d' ' -f1)
    local session_turns
    session_turns=$(echo "$session_info" | cut -d' ' -f2)

    # Get global turn count for naming
    local global_turn
    global_turn=$(python3 -c "
import json
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state.get('total_turns', 0) + 1)
except:
    print(1)
" 2>/dev/null)

    # Determine if we need a new session (rotation)
    local need_new_session=0
    if [[ -z "$current_session_id" ]] || [[ "$current_session_id" == " " ]]; then
        need_new_session=1
    elif (( session_turns >= MAX_SESSION_TURNS )); then
        need_new_session=1
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Session rotation: turn $session_turns/$MAX_SESSION_TURNS. Creating new session." >> "$LOG_FILE"
    fi

    # Build opencode command
    local output_file
    output_file=$(mktemp /tmp/opencode_output.XXXXXX.json)
    local title
    if [[ $need_new_session -eq 1 ]]; then
        session_turns=0
        title="[UNATTENDED] Agent-daryl turn #${global_turn} (session #$(python3 -c "import json; s=json.load(open('$STATE_FILE')); print(s.get('unattended_session', {}).get('session_number', 1))" 2>/dev/null || echo 1))"
        # Increment session number for next time
        python3 -c "
import json
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    if 'unattended_session' not in state:
        state['unattended_session'] = {}
    state['unattended_session']['session_number'] = state['unattended_session'].get('session_number', 1) + 1
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except: pass
" 2>/dev/null
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Creating new session: $title" >> "$LOG_FILE"
    else
        title="[UNATTENDED] Agent-daryl turn #${global_turn} (continuing)"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Continuing session $current_session_id (turn $((session_turns+1))/$MAX_SESSION_TURNS)." >> "$LOG_FILE"
    fi

    local turn_exit=0
    local turn_output_file
    turn_output_file=$(mktemp /tmp/opencode_stdout.XXXXXX.log)

    cd "$WORKSPACE"

    if [[ $need_new_session -eq 1 ]]; then
        # New session
        "$OPENCODE_BIN" run --format json --title "$title" "$prompt" > "$output_file" 2>"$turn_output_file" || turn_exit=$?
    else
        # Continue existing session
        "$OPENCODE_BIN" run --format json --session "$current_session_id" "$prompt" > "$output_file" 2>"$turn_output_file" || turn_exit=$?
    fi

    # Extract session ID from output (for new sessions)
    local extracted_session_id=""
    if [[ $need_new_session -eq 1 ]]; then
        extracted_session_id=$(extract_session_id "$output_file")
        if [[ -n "$extracted_session_id" ]]; then
            current_session_id="$extracted_session_id"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] New session created: $current_session_id" >> "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] WARNING: Could not extract session ID from output." >> "$LOG_FILE"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Output preview:" >> "$LOG_FILE"
            head -c 2000 "$output_file" >> "$LOG_FILE" 2>/dev/null || true
        fi
    fi

    # Update session info
    if [[ -n "$current_session_id" ]] && [[ "$current_session_id" != " " ]]; then
        local new_session_turns=$((session_turns + 1))
        update_session_info "$current_session_id" "$new_session_turns" "$global_turn"
    fi

    # Log results
    if [[ $turn_exit -eq 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Turn completed successfully." >> "$LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TURN STDERR]" >> "$LOG_FILE"
        cat "$turn_output_file" >> "$LOG_FILE" 2>/dev/null || true
        echo "..." >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Turn exited with code $turn_exit." >> "$LOG_FILE"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TURN ERROR]" >> "$LOG_FILE"
        cat "$turn_output_file" >> "$LOG_FILE" 2>/dev/null || true
    fi

    # Cleanup temp files
    rm -f "$output_file" "$turn_output_file"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Turn finished. Next check in 15 minutes." >> "$LOG_FILE"
}

# Main execution
main() {
    mkdir -p "$(dirname "$LOG_FILE")"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] Scheduler check started." >> "$LOG_FILE"

    # Check if enabled
    if ! check_enabled; then
        exit 0
    fi

    # Check lock (prevent overlapping turns)
    if ! check_lock; then
        exit 0
    fi

    # Check GPU utilization before starting a turn
    if ! check_gpu_utilization; then
        exit 0
    fi

    # Set lock
    set_lock

    # Run the turn
    run_turn
}

main "$@"
