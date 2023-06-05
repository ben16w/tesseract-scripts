#!/usr/bin/env bash

## Configuration
KOPIA_BACKUP_LOG_DIR="/var/log/kopia/"
KOPIA_BACKUP_LOG_LEVEL="debug"
KOPIA_BACKUP_VERIFY_PERCENT="0.3"
LOG_FILE="/var/log/tesseract.log"
EMAIL_USERNAME=""


# Set global variables
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -f "$SCRIPT_DIR"/.env ]; then
    source "$SCRIPT_DIR"/.env || exit 1
fi

function error_exit()
{
    echo "$(date '+%F %T.%3N') ERROR: ${1:-"Unknown Error"}" | tee -a "$LOG_FILE"

    if [ "${EMAIL_USERNAME}" != "" ]; then

msmtp -t <<EOF
To: ${EMAIL_USERNAME}
From: ${EMAIL_USERNAME}
Subject: $(hostname): Script $0 has encountered an error - ${1:-"Unknown Error"}

Hostname: $(hostname)
Logs:
$(tail -n 10 "$LOG_FILE")
EOF

    else
        log "No email sent. EMAIL_USERNAME not set."
    fi
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
    kopia snapshot create "$backup_dir" --file-log-level="$KOPIA_BACKUP_LOG_LEVEL" --log-dir="$KOPIA_BACKUP_LOG_DIR"
    response=$?
    if [ $response -ne 0 ]; then
        error_exit "Kopia command failed."
    fi

    kopia snapshot verify --verify-files-percent="$KOPIA_BACKUP_VERIFY_PERCENT" --file-parallelism=10 --parallel=10
    response=$?
    if [ $response -ne 0 ]; then
        error_exit "Kopia verify command failed."
    fi

done

log "Cloud backup of path $backup_dir finished!"
