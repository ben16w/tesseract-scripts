#!/usr/bin/env bash

# Set variables
VOLUME_FILE=./volume # the file path for the encrypted volume
VOLUME_SIZE=4G # default size of the volume
VOLUME_PASSWORD=password # default password for the volume
VOLUME_ADD_DATA=false # whether to add sample data to the volume or not
TMP_DIR="" # temporary directory to mount filesystem
TMP_CRYPT=/dev/mapper/temp_provision_disk # the path for the temporary encrypted volume
SAMPLE_FILES_NUM=10
SAMPLE_DIRS=(
    "Tvshows"
    "Audio"
    "Music"
    "Nextcloud"
    "Downloads"
    "Ebooks"
)

# Set global variables
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -f "$SCRIPT_DIR"/.env ]; then
    source "$SCRIPT_DIR"/.env || exit 1
fi

# Function to exit the script with an error message.
function error_exit()
{
    echo "$(date '+%F %T.%3N') ERROR: ${1:-"Unknown Error"}"
    exit 1
}

# Function to print an informational message.
function log()
{
    echo "$(date '+%F %T.%3N') INFO: ${1}"
}

# Function to print the script usage message.
function usage()
{
    echo "Usage: $(basename "$0") [-s <SIZE>] [-p <PASSWORD>] [-d] <VOLUME_FILE>"
    echo "Create an encrypted volume with specified size and password, and add sample data if specified."
    echo ""
    echo "  -s size        Set the size of the volume, default is 4G."
    echo "  -p password    Set the password of the volume, default is 'password'."
    echo "  -d             Add sample data to the volume, default is false."
    echo "  VOLUME_FILE    The file path of the volume to create."
    echo ""
    exit 0
}

# Function to clean up the temporary directory and device mapper.
function cleanup()
{
    log "Cleaning up"

    # Unmount the encrypted volume.
    umount "$TMP_DIR" || true

    # Close the encrypted volume with LUKS.
    cryptsetup luksClose "$TMP_CRYPT" || true

    # Remove the temporary directory.
    rm -rf "$TMP_DIR" || true
}

# Register the cleanup function to be called on exit.
trap cleanup SIGINT SIGTERM SIGHUP EXIT

# Check if script is running as root.
if [[ $EUID -ne 0 ]]; then
    error_exit "Script $0 must be run as root" 
fi

# Check if user requested the script usage message.
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

# Check that cryptsetup is installed
if ! command -v cryptsetup &> /dev/null; then
    error_exit "cryptsetup could not be found."
fi

# Check that a path argument has been given.
if [ $# -lt 1 ]; then
    error_exit "No path argument supplied."
fi

# Parse any command line options using getopts.
while getopts "s:p:d" flag; do
    case "${flag}" in
        s) VOLUME_SIZE=${OPTARG};;
        p) VOLUME_PASSWORD=${OPTARG};;
        d) VOLUME_ADD_DATA=true;;
        ?) usage;;
    esac
done

# Get the volume file path from the remaining command line arguments.
VOLUME_FILE=${*: $OPTIND:1}

# Check if the volume file already exists
if [ -f "$VOLUME_FILE" ]; then
    error_exit "File already exists."
fi

# Check if the parent directory of the volume file exists.
DIRECTORY=$(dirname "$VOLUME_FILE")
if [ ! -d "$DIRECTORY" ]; then
    error_exit "$DIRECTORY does not exist."
fi

# Check that the filename is at least 2 characters long.
FILENAME=$(basename "$VOLUME_FILE")
if [ ${#FILENAME} -lt 2 ]; then
    error_exit "Filename '$FILENAME' is too short."
fi

# Create a temporary directory.
if ! TMP_DIR=$(mktemp -d); then
    log "Failed to create temporary directory"
fi

# Check that the temporary directory is empty.
if [ "$(ls -A "$TMP_DIR")" ]; then
    error_exit "Temp directory $TMP_DIR not empty."
fi

# Allocate disk space for the encrypted volume.
if ! fallocate -l "$VOLUME_SIZE" "$VOLUME_FILE"; then
    error_exit "Failed to allocate disk space for encrypted volume."
fi

# Format the volume with LUKS encryption. The -q and -y options avoid interactive prompts.
if ! echo -n "$VOLUME_PASSWORD" | cryptsetup -q -y luksFormat "$VOLUME_FILE"; then
    error_exit "Failed to format volume with LUKS encryption."
fi

# Open the encrypted volume with LUKS.
if ! echo -n "$VOLUME_PASSWORD" | cryptsetup luksOpen "$VOLUME_FILE" "$(basename $TMP_CRYPT)"; then
    error_exit "Failed to open encrypted volume with LUKS."
fi

# Format the volume with the ext4 file system.
if ! mkfs.ext4 "$TMP_CRYPT"; then
    error_exit "Failed to format volume with ext4 file system."
fi

# If the user has selected to add data to the volume
# then create sample files with random content, set permissions and ownership.
if [ "$VOLUME_ADD_DATA" != "false" ]; then

    log "Adding sample data."

    # Mount the encrypted volume.
    mount "$TMP_CRYPT" "$TMP_DIR"

    # Loop through each directory in SAMPLE_DIRS and create sample files in each directory.
    for dir in "${SAMPLE_DIRS[@]}"; do
        mkdir "$TMP_DIR/$dir"
        for (( i=1; i<=SAMPLE_FILES_NUM; i++ )); do
        # Create a sample file filled with random data
        dd if=/dev/urandom bs=1M count=8 of="$TMP_DIR/$dir/samplefile-$i"
        
        # Set file permissions to allow read, write, and execute for all users
        chmod 777 "$TMP_DIR/$dir/samplefile-$i"
        
        # Set file ownership to user ID 1000 and group ID 1000
        chown 1000:1000 "$TMP_DIR/$dir/samplefile-$i"
        done
    done

    mkdir "$TMP_DIR/Movies"
    wget -q "https://samples.tdarr.io/api/v1/samples/sample__1080__libx264__alac__30s__video.mkv" \
        -O "$TMP_DIR/Movies/Big Buck Bunny (2008).mkv"

    mkdir "$TMP_DIR/Photos"
    for i in {1..25}; do
        wget -q "https://picsum.photos/800" \
        -O "$TMP_DIR/Photos/photo$i.jpg"
    done

fi

log "Finished!"
