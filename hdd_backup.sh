#!/usr/bin/env bash

# Set variables
STORAGE_PATH=/media/storage/
HDD_UUID=$1
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TMP_DIR=$(mktemp -d) # Generate a temp directory
EXCLUDE_DIRS=(
    "snapraid.content"
    "Downloads"
    "Import"
    "Tvshows"
)

function usage()
{
    echo "Usage: $(basename "$0") <HDD_UUID>"
    echo
    echo "Options:"
    echo "  -h, --help         Show this help message and exit"
    echo
    echo "Arguments:"
    echo "  HDD_UUID           The UUID of the encrypted external hard drive"
    echo
    echo "Description:"
    echo "  This script backs up files from a source directory to an encrypted external hard drive."
    echo "  The HDD_UUID argument is required and should be the UUID of the external hard drive."
    echo
}

function error_exit()
{
    echo "$(date '+%F %T.%3N') ERROR: ${1:-"Unknown Error"}"
    exit 1
}

function log()
{
    echo "$(date '+%F %T.%3N') INFO: ${1}"
}

# Function to clean up the temporary directory and device mapper
function cleanup()
{
    log "Cleaning up"

    # Unmount the encrypted volume
    umount "$TMP_DIR" || true

    # Remove the temporary directory
    rm -rf "$TMP_DIR" || true

    # Close the encrypted volume with LUKS
    cryptsetup luksClose "luks-$HDD_UUID" || true
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
fi

# Build rsync exclude parameters string from array
EXCLUDE_PARAMS=""
for dir in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_PARAMS+="--exclude=\"$dir\" "
done

# Load in any .env files
if [ -f "$SCRIPT_DIR"/.env ]; then
    source "$SCRIPT_DIR"/.env || exit 1
fi

# Need to check that rsync is installed
if ! command -v rsync >/dev/null 2>&1; then
    error_exit "Required command rsync is not installed or not available in the PATH"
fi

# Need to check that cryptsetup is installed
if ! command -v cryptsetup >/dev/null 2>&1; then
    error_exit "Required command cryptsetup is not installed or not available in the PATH"
fi

# Check for sudo
if [[ $EUID -ne 0 ]]; then
    error_exit "Script $0 must be run as root" 
fi

# Check that a UUID argument has been given.
if [ $# -lt 1 ]; then
    usage
    error_exit "No UUID argument supplied."
fi

# Check if mktemp command succeeded
if [ ! -d "$TMP_DIR" ]; then
    error_exit "Failed to create temporary directory"
fi

if [ -z "$HDD_UUID" ]; then
    echo "Destination HDD not found"
    exit 1
fi

# Check if HDD is already mounted
if grep -q "^/dev/mapper/luks-$HDD_UUID" /proc/mounts; then
    error_exit "Destination HDD is already mounted."
fi

# Check that storage directory exists.
if [ ! -d "$STORAGE_PATH" ]; then
    error_exit "Storage directory not found."
fi

# Check that storage directory has files in
if [ ! "$(ls -A "$STORAGE_PATH")" ]; then
    error_exit "Storage directory $STORAGE_PATH is empty. Nothing to backup."
fi

# Register the cleanup function to be called on exit
trap cleanup SIGINT SIGTERM SIGHUP EXIT

log "Unlocking HDD"

# Unlock the LUKS-encrypted hard drive
if ! cryptsetup luksOpen "/dev/disk/by-uuid/$HDD_UUID" "luks-$HDD_UUID"; then
    error_exit "Unlock error"
fi

# Mount the unlocked hard drive to the temporary directory
if ! mount "/dev/mapper/luks-$HDD_UUID" "$TMP_DIR"; then
    error_exit "Mount error"
fi

# Use rsync to copy files from the source directory to the temporary directory
if ! rsync \
-artvu \                   # Preserve file attributes, recurse into subdirectories, show progress, update files
--del \                    # Delete files from destination that do not exist in source
--prune-empty-dirs \       # Remove empty directories from destination
$EXCLUDE_PARAMS \          # Exclude specific files or directories from the sync
"$STORAGE_PATH" \          # Source directory
"$TMP_DIR"                 # Destination directory
then
    error_exit "Rsync command failed."
fi



log "Backup finished"
