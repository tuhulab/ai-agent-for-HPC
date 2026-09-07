#!/bin/bash

# Restic Wrapper Script for UCloud Periodic Backups
# This script automates the setup, backup, and restoration of data using Restic
# Documentation: https://docs.cloud.sdu.dk/hands-on/periodic-backup.html

# Function to install Restic and cron, and configure Restic
set_up_restic () {
        (sudo apt-get update; \
         sudo apt-get install -y cron restic; \
         sudo restic self-update; \
         sudo restic generate --bash-completion /etc/bash_completion.d/restic; \
         sudo cron) >/dev/null 2>&1
}

# Function to update the crontab with new jobs
update_crontab () {
        (crontab -l 2>/dev/null; echo "$1") | crontab -
}

# Initialize variables
ACTION=""
RESTIC_REPOSITORY=""
RESTIC_SOURCE=""
RESTIC_TARGET=""
RESTIC_PASSWORD_FILE=""
EXTRA_ARGS=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        backup|restore)
            ACTION="$1"
            shift
            ;;
        -r)
            RESTIC_REPOSITORY="$2"
            shift 2
            ;;
        -s)
            RESTIC_SOURCE="$2"
            shift 2
            ;;
        -t)
            RESTIC_TARGET="$2"
            shift 2
            ;;
        -p)
            RESTIC_PASSWORD_FILE="$2"
            shift 2
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

# Validate required inputs
if [[ -z "${ACTION}" ]]; then
    echo "Error: No action specified (backup or restore required)."
    exit 1
elif [[ -z "$RESTIC_REPOSITORY" || -z "$RESTIC_PASSWORD_FILE" ]]; then
    echo "Error: Missing required parameters. Please specify the repository (-r), and password file (-p)."
    exit 1
fi

# Ensure absolute paths are used
export RESTIC_REPOSITORY=$(readlink -f "$RESTIC_REPOSITORY")
export RESTIC_PASSWORD_FILE=$(readlink -f "$RESTIC_PASSWORD_FILE")

# Add environment variables to bashrc
echo "export RESTIC_REPOSITORY=$RESTIC_REPOSITORY" >> "/home/$USER/.bashrc"
echo "export RESTIC_PASSWORD_FILE=$RESTIC_PASSWORD_FILE" >> "/home/$USER/.bashrc"

# Setup Restic and initialize repository if necessary
set_up_restic
restic snapshots >/dev/null 2>&1 || restic init

# Perform backup or restoration based on user input
if [[ ${ACTION} == "backup" ]]; then
    export RESTIC_SOURCE=$(readlink -f "$RESTIC_SOURCE")
    restic --password-file "$RESTIC_PASSWORD_FILE" -r "$RESTIC_REPOSITORY" backup --host UCloud --verbose "$RESTIC_SOURCE" "${EXTRA_ARGS[@]}"
    echo "Backup scheduled successfully."

    # Schedule periodic backup job (e.g., every 2 hours)
    BACKUP_JOB="0 */2 * * * restic --password-file $RESTIC_PASSWORD_FILE -r $RESTIC_REPOSITORY backup --host UCloud --verbose $RESTIC_SOURCE ${EXTRA_ARGS[@]} >> /work/backup.log"
    update_crontab "$BACKUP_JOB"
    crontab -l
elif [[ ${ACTION} == "restore" ]]; then
    restic -r "$RESTIC_REPOSITORY" restore latest --password-file "$RESTIC_PASSWORD_FILE" --target "$RESTIC_TARGET" --host UCloud "${EXTRA_ARGS[@]}"
    echo "Data restoration initiated."
fi
