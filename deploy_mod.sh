#!/bin/bash

# --- Default Configuration ---
# These values will be used if no command-line flags are provided.
DEFAULT_SSH_PORT="222"
DEFAULT_SSH_USER="steam"
DEFAULT_HOST="asean-mt-server"
DEFAULT_SOURCE_DIR="./MotorTownMods/Scripts"
DEFAULT_DEST_DIR="/var/lib/motortown-server/MotorTown/Binaries/Win64/ue4ss/Mods/MotorTownMods/Scripts"
DEFAULT_STOP_PORT="55001"
DEFAULT_RELOAD_PORT="55000"

# --- Function to Display Usage Information ---
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script synchronizes a local directory with a remote server and then sends"
    echo "requests to restart and reload a service on that server."
    echo ""
    echo "Options:"
    echo "  -p, --ssh-port PORT       Specify the SSH port for rsync. (Default: $DEFAULT_SSH_PORT)"
    echo "  -u, --user USER           Specify the SSH username. (Default: $DEFAULT_SSH_USER)"
    echo "  -h, --host HOST           Specify the remote host for both rsync and curl. (Default: $DEFAULT_HOST)"
    echo "  -s, --source DIR          Specify the local source directory to sync. (Default: $DEFAULT_SOURCE_DIR)"
    echo "  -d, --dest DIR            Specify the remote destination directory. (Default: $DEFAULT_DEST_DIR)"
    echo "      --stop-port PORT      Specify the port for the 'stop' API endpoint. (Default: $DEFAULT_STOP_PORT)"
    echo "      --reload-port PORT    Specify the port for the 'reload' API endpoint. (Default: $DEFAULT_RELOAD_PORT)"
    echo "      --help                Display this help message and exit."
    exit 1
}

# --- Argument Parsing ---
# Initialize variables with default values
SSH_PORT=$DEFAULT_SSH_PORT
SSH_USER=$DEFAULT_SSH_USER
HOST=$DEFAULT_HOST
SOURCE_DIR=$DEFAULT_SOURCE_DIR
DEST_DIR=$DEFAULT_DEST_DIR
STOP_PORT=$DEFAULT_STOP_PORT
RELOAD_PORT=$DEFAULT_RELOAD_PORT

# Process command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--ssh-port) SSH_PORT="$2"; shift ;;
        -u|--user) SSH_USER="$2"; shift ;;
        -h|--host) HOST="$2"; shift ;;
        -s|--source) SOURCE_DIR="$2"; shift ;;
        -d|--dest) DEST_DIR="$2"; shift ;;
        --stop-port) STOP_PORT="$2"; shift ;;
        --reload-port) RELOAD_PORT="$2"; shift ;;
        --help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# --- Main Execution ---

# Create a secure temporary directory for file processing
# Using mktemp is safer than creating a fixed-name directory
TEMP_DIR=$(mktemp -d)

# Set up a trap to ensure the temporary directory is cleaned up when the script exits,
# even if it fails or is interrupted (e.g., with Ctrl+C).
trap 'echo ""; echo "--- Cleaning up temporary files ---"; rm -rf "$TEMP_DIR"' EXIT

echo "Copying source files to a temporary location for processing..."
cp ${SOURCE_DIR}/*.lua "${TEMP_DIR}/"

echo "Converting line endings to Windows format (CRLF)..."
find "$TEMP_DIR" -type f -name "*.lua" -exec sed -i 's/$/\r/' {} +
#find "$TEMP_DIR" -type f -name "*.lua" -exec sed -i 's/\r$//' {} +;
echo "Conversion complete."
echo ""


# Construct the remote target for rsync
REMOTE_TARGET="${SSH_USER}@${HOST}:${DEST_DIR}"

# Construct the curl URLs
STOP_URL="http://${HOST}:${STOP_PORT}/stop"
RELOAD_URL="http://${HOST}:${RELOAD_PORT}/mods/reload"

echo "--- Configuration ---"
echo "Source:         $SOURCE_DIR"
echo "Destination:    $REMOTE_TARGET"
echo "SSH Port:       $SSH_PORT"
echo "Stop URL:       $STOP_URL"
echo "Reload URL:     $RELOAD_URL"
echo "---------------------"
echo ""

# 1. Synchronize files to the remote server using scp
echo "STEP 1: Syncing files with scp..."
# We now upload the converted files from our temporary directory
scp -P ${SSH_PORT} ${TEMP_DIR}/VehicleManager.lua "${REMOTE_TARGET}"
echo "Sync complete."
echo ""

# 2. Stop the mod server
echo "STEP 2: Sending 'stop' command to the server..."
curl -X POST "${STOP_URL}"
echo ""
echo "Stop command sent."
echo ""
sleep 5

# 3. Reload the mod server via the management server
echo "STEP 3: Sending 'reload' command to the management server..."
curl -X POST "${RELOAD_URL}" -d ""
echo ""
echo "Reload command sent."
echo ""
echo "--- Script Finished ---"
