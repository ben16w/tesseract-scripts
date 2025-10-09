#!/usr/bin/env bash


####  CONFIGURATION  ####

KOPIA_BACKUP_LOG_DIR="/var/log/kopia/"
KOPIA_BACKUP_LOG_LEVEL="debug"
KOPIA_BACKUP_VERIFY_PERCENT="0.3"
KOPIA_BACKUP_VERIFY_ENABLED="true"
KOPIA_BACKUP_PARALLELISM="10"

function usage()
{
    echo "Kopia to BackBlaze backup for specified path."
    echo
    exit 0
}

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/shared.sh"

####  MAIN CODE  ####

# Check that a path argument has been given.
if [ -z "$1" ]; then
        error_exit "No path arguments supplied."
fi

# Need to check that kopia is installed
if ! command -v kopia >/dev/null 2>&1; then
    error_exit "Required command kopia is not installed or not available in the PATH"
fi

for backup_dir in "$@"; do

    info "Cloud backup of path $backup_dir starting"

    # Check if another instance of kopia is running
    pidof -o %PPID -x kopia >/dev/null && error_exit "Kopia is already running"

    # Check that path has files in it
    if [ ! "$(ls -A "$backup_dir")" ]; then
        error_exit "Path $backup_dir empty."
    fi

    # Everything goes to file. Maybe should be 2> | tee -a file
    kopia snapshot create \
        "$backup_dir" \
        --file-log-level="$KOPIA_BACKUP_LOG_LEVEL" \
        --log-dir="$KOPIA_BACKUP_LOG_DIR" \
        --parallel="$KOPIA_BACKUP_PARALLELISM"
    response=$?
    if [ $response -ne 0 ]; then
        error_exit "Kopia command failed."
    fi

done

if [ "$KOPIA_BACKUP_VERIFY_ENABLED" = "true" ]; then
    info "Starting verification of kopia repository"

    kopia snapshot verify \
        --verify-files-percent="$KOPIA_BACKUP_VERIFY_PERCENT" \
        --parallel="$KOPIA_BACKUP_PARALLELISM" \
        --file-parallelism="$KOPIA_BACKUP_PARALLELISM"
    response=$?
    if [ $response -ne 0 ]; then
        error_exit "Kopia verify command failed."
    fi
else
    info "Kopia verification is disabled"
fi

info "Cloud backup of path $backup_dir finished!"
