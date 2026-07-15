claude_at() {
    local session_name="$1"
    # Accept variable time arguments (everything after the first arg)
    local run_time="${*:2}"
    local current_tty

    # Help menu check
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: claude_at <tmux_session> <time>"
        echo ""
        echo "Schedules a non-interactive resume command into a running tmux session at a specific time using 'at'."
        echo ""
        echo "Arguments:"
        echo "  <tmux_session>  Name of the target active tmux session (e.g., interleaf)"
        echo "  <time>          Execution time. May contain multiple words for 'at' (e.g., '5:01 PM' or 'now + 2 minutes')"
        echo ""
        echo "Examples:"
        echo "  claude_at my_tmux_session_name 12:01"
        echo "  claude_at my_tmux_session_name 5:01 PM"
        echo "  claude_at my_tmux_session_name now + 2 minutes"
        return 0
    fi

    # Validation check for missing arguments
    if [[ -z "$session_name" || -z "$run_time" ]]; then
        echo "Error: Missing arguments."
        echo "Try 'claude_at --help' for more information."
        return 1
    fi

    current_tty=$(tty)

    # Try to compute the effective scheduled time as a full ISO 8601 timestamp.
    # date -d accepts many of the same formats as at; if it fails, leave blank.
    local effective_time_create
    effective_time_create=$(date -d "$run_time" --iso-8601=seconds 2>/dev/null || true)

    # Build the script that will be run by 'at'.
    # Keep the $(date -Iseconds) literal so it's evaluated when the job runs.
    at_script=$(cat <<AT_SCRIPT
/usr/bin/tmux send-keys -t ${session_name} "claude --continue --dangerously-skip-permissions" Enter
logger -t claude_at "Executed at job: input_time='${run_time}' effective_time='\$(date -Iseconds)' session='${session_name}'"
/bin/echo "[at job] Claude session resumed in tmux." > ${current_tty}
AT_SCRIPT
)

    # Schedule the at job and capture the at command output (job number / scheduling info).
    job_info=$(printf "%s" "$at_script" | at "$run_time" 2>&1)
    at_exit_code=$?

    if [[ $at_exit_code -ne 0 ]]; then
        echo "Failed to schedule at job: $job_info"
        logger -t claude_at "Failed to schedule at job: input_time='${run_time}' session='${session_name}' error='${job_info//$'\n'/ }'"
        return $at_exit_code
    fi

    # Log to the system logger that the at job was created, including both the input time and the effective ISO time.
    # Include the raw output from at for traceability.
    # Normalize newlines in job_info for a single-line log entry.
    job_info_single_line=$(printf "%s" "$job_info" | tr '\n' ' ')
    logger -t claude_at "Scheduled at job: input_time='${run_time}' effective_time='${effective_time_create}' session='${session_name}' at_output='${job_info_single_line}'"

    # Also echo a user-facing confirmation to the current tty.
    echo "Scheduled claude resume for session '${session_name}' at '${run_time}'."

    return 0
}

_omb_plugin_tmux_directory_session_name() {
    # Shared logic with oh-my-bash tds plugin to derive the tmux session name.
    # Returns the session name in the format: <directory>-<6char-md5-hash>
    local dir=${PWD##*/}
    local md5
    if _omb_util_command_exists md5sum; then
        md5=$(printf '%s' "$PWD" | md5sum | cut -d ' ' -f 1)
    elif _omb_util_command_exists md5; then
        md5=$(printf '%s' "$PWD" | md5)
    else
        echo "[oh-my-bash] claude_at_tds: md5sum or md5 not found, tds requires one of them" >&2
        return 1
    fi
    echo "${dir}-${md5:0:6}"
}

claude_at_tds() {
    # Accept variable time arguments (everything after the first arg)
    local run_time="${*:1}"
    local session_name

    # Help menu check
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: claude_at_tds <time>"
        echo ""
        echo "Schedules a non-interactive claude resume for the current directory's tmux session at a specific time."
        echo "Automatically detects the tmux session name from the current working directory (using oh-my-bash tds convention)."
        echo ""
        echo "Arguments:"
        echo "  <time>  Execution time. May contain multiple words for 'at' (e.g., '5:01 PM' or 'now + 2 minutes')"
        echo ""
        echo "Examples:"
        echo "  claude_at_tds 12:01"
        echo "  claude_at_tds 5:01 PM"
        echo "  claude_at_tds now + 2 minutes"
        return 0
    fi

    # Validation check for missing arguments
    if [[ -z "$run_time" ]]; then
        echo "Error: Missing time argument."
        echo "Try 'claude_at_tds --help' for more information."
        return 1
    fi

    # Derive the session name using the same logic as oh-my-bash tds
    session_name=$(_omb_plugin_tmux_directory_session_name)
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    # Check if the session exists in tmux
    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        echo "Error: Tmux session '$session_name' not found."
        echo "Current directory: $(pwd)"
        echo "To create a session using tds, run: tds"
        return 1
    fi

    # Call claude_at with the detected session and provided time
    claude_at "$session_name" $run_time
}
