#!/usr/bin/env bash

# TODO
# Fix bug in the do_backup find commands

## Configuration
BACKUP_DESTINATION="{{ local_backup_destination }}"
BACKUP_RETENTION_DAILY="{{ local_backups_daily }}"
BACKUP_RETENTION_WEEKLY="{{ local_backups_weekly }}"
BACKUP_RETENTION_MONTHLY="{{ local_backups_monthly }}"
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
    echo "Local backup"
    exit 0
fi

# Check that a path argument has been given.
if [ -z "$1" ]; then
        error_exit "No path arguments supplied."
fi

# Check backup destination
if [ ! -d "$BACKUP_DESTINATION" ]; then
    error_exit "No backup destination $BACKUP_DESTINATION."
fi

for backup_path in "$@"; do

    log "Local backup of path $backup_path starting."

    backup_name=$(basename "$backup_path")

    # Check if another instance of script is running
    pidof -o %PPID -x "$0" >/dev/null && error_exit "Script $0 already running"

    # Check backup path exists.
    if [ ! -d "$backup_path" ]; then
        error_exit "No backup path $backup_path."
    fi

    # Check that local backup path has files in it
    if [ ! "$(ls -A "$backup_path")" ]; then
        error_exit "Local backup path $backup_path empty."
    fi

    # Check if Docker exists and get list of running containers
    docker_found=0
    if command -v docker &> /dev/null; then
        log "Docker found of system. Getting list of running containers"
        mapfile -t running_containers < <(docker ps -q)
        if [ ${#running_containers[@]} -ne 0 ]; then
            docker_found=1
        else
            log "No containers running"
            docker_found=0
        fi
    else
        log "Docker not found on system."
    fi

    MONTH=$(date +%d)
    DAYWEEK=$(date +%u)

    if [[ ${MONTH#0} -eq 1  ]];
            then
            FN='monthly'
    elif [[ ${DAYWEEK#0} -eq 7  ]];
            then
            FN='weekly'
    elif [[ ${DAYWEEK#0} -lt 7 ]];
            then
            FN='daily'
    fi

    DATE=$FN-$(date +"%Y%m%d")

    function do_backup
    {
        cd "$BACKUP_DESTINATION/" || error_exit
        filename="$backup_name-backup-$DATE.tar.gz"
        if [ -f "$filename" ]; then
            log "Backup $filename has already been made for today."
            return
        fi

        if [[ docker_found -eq 1 ]]; then
            log "Stopping Docker containers."
            docker stop "${running_containers[@]}" &>> "$LOG_FILE"
            if [ $? -ne 0 ]; then
                error_exit "Docker stop command failed."
            fi
        fi

        log "Creating archive from path."
        tar --warning=no-file-changed -p -zcf "$filename" "$backup_path" &>> "$LOG_FILE"
        if [ $? -ne 0 ]; then
            error_exit "Tar command failed."
        fi

        if [[ docker_found -eq 1 ]]; then
            log "Starting Docker containers."
            docker start "${running_containers[@]}" &>> "$LOG_FILE"
            if [ $? -ne 0 ]; then
                error_exit "Docker start command failed."
            fi
        fi

        find ./ -type f -name "$backup_name-backup-daily*.tar.gz" -printf '%T@ %p\n' | sort -k1 -nr | sed 's/.* //g' \
            | sed -e 1,"$BACKUP_RETENTION_DAILY"d | xargs -d '\n' rm -R > /dev/null 2>&1
        find ./ -type f -name "$backup_name-backup-weekly*.tar.gz" -printf '%T@ %p\n' | sort -k1 -nr | sed 's/.* //g' \
            | sed -e 1,"$BACKUP_RETENTION_WEEKLY"d | xargs -d '\n' rm -R > /dev/null 2>&1
        find ./ -type f -name "$backup_name-backup-monthly*.tar.gz" -printf '%T@ %p\n' | sort -k1 -nr | sed 's/.* //g' \
            | sed -e 1,"$BACKUP_RETENTION_MONTHLY"d | xargs -d '\n' rm -R > /dev/null 2>&1

    }

    if [[ ( -n "$BACKUP_RETENTION_DAILY" ) && ( $BACKUP_RETENTION_DAILY -ne 0 ) && ( $FN == daily ) ]]; then
        do_backup
    fi
    if [[ ( -n "$BACKUP_RETENTION_WEEKLY" ) && ( $BACKUP_RETENTION_WEEKLY -ne 0 ) && ( $FN == weekly ) ]]; then
        do_backup
    fi
    if [[ ( -n "$BACKUP_RETENTION_MONTHLY" ) && ( $BACKUP_RETENTION_MONTHLY -ne 0 ) && ( $FN == monthly ) ]]; then
        do_backup
    fi

    log "Local backup of path $backup_path completed"

done

{% endraw %}