#!/usr/bin/env bash

## Configuration
LOG_DIR="{{ cloud_backup_log_dir }}"
LOG_LEVEL="{{ cloud_backup_log_level }}"
LOG_FILE="{{ log_file }}"
EMAIL_USERNAME="{{ email_username }}"

{% raw %}

# Set global variables
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -f "$SCRIPT_DIR"/.env ]; then
    source "$SCRIPT_DIR"/.env || exit 1
fi

function error_exit()
{
    echo "$(date '+%F %T.%3N') ERROR: ${1:-"Unknown Error"}" | tee -a "$LOG_FILE"

msmtp -t <<EOF
To: ${EMAIL_USERNAME}
From: ${EMAIL_USERNAME}
Subject: $(hostname): Script $0 has encountered an error - ${1:-"Unknown Error"}

Hostname: $(hostname)
Logs:
$(tail -n 10 "$LOG_FILE")
EOF
    exit
}

function log()
{
    echo "$(date '+%F %T.%3N') INFO: ${1}" | tee -a "$LOG_FILE"
}

if [[ $EUID -ne 0 ]]; then
    error_exit "Script $0 must be run as root" 
fi

# PUT SCRIPT INFO IN HERE
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Kopia to BackBlaze backup for specified path."
    exit 0
fi

# Check that a path argument has been given.
if [ -z "$1" ]; then
        error_exit "No path arguments supplied."
fi

for backup_dir in "$@"; do

    log "Cloud backup of path $backup_dir starting"

    # Check if another instance of kopia is running
    pidof -o %PPID -x kopia >/dev/null && error_exit "Kopia is already running"

    # Check that path has files in it
    if [ ! "$(ls -A "$backup_dir")" ]; then
        error_exit "Path $backup_dir empty."
        exit
    fi

    # Everything goes to file. Maybe should be 2> | tee -a file
    kopia snapshot "$backup_dir" --file-log-level="$LOG_LEVEL" --log-dir="$LOG_DIR"
    response=$?
    if [ $response -ne 0 ]; then
        error_exit "Kopia command failed."
    fi

done

log "Cloud backup of path $backup_dir finished!"

{% endraw %}