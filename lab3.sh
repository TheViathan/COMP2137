#!/bin/bash

# variables
VERBOSE=false
SCRIPT_NAME="configure-host.sh"

# Checks if script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# gets the original user who invoked sudo
USER=$(logname)

# parses arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# checks if script exists in same directory
if [[ ! -f $SCRIPT_NAME ]]; then
    echo "Error: $SCRIPT_NAME not found!"
    exit 1
fi

# if verbose flag is used, sets it for remote execution as well
REMOTE_VERBOSE=""
if $VERBOSE; then
    REMOTE_VERBOSE="-verbose"
fi

# deploys the configure script and executes it on servers
deploy() {
    local SERVER="$1"
    local HOSTNAME="$2"
    local IP="$3"
    local HOSTENTRY_NAME="$4"
    local HOSTENTRY_IP="$5"

    echo "Processing $SERVER..."

    # transfers the script using the original user (-u) to ensure ssh key usage
    sudo -u "$USER" scp -o StrictHostKeyChecking=no "$SCRIPT_NAME" "remoteadmin@$SERVER:/root/"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to transfer script to $SERVER"
        exit 1
    fi

    # executes the script as the original user
    sudo -u "$USER" ssh -o StrictHostKeyChecking=no "remoteadmin@$SERVER" -- "chmod +x /root/$SCRIPT_NAME"
    sudo -u "$USER" ssh -o StrictHostKeyChecking=no "remoteadmin@$SERVER" -- "/root/$SCRIPT_NAME -name $HOSTNAME -ip $IP -hostentry $HOSTENTRY_NAME $HOSTENTRY_IP $REMOTE_VERBOSE"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to execute script on $SERVER"
        exit 1
    fi
}

# deploys to server1
deploy "server1-mgmt" "loghost" "192.168.16.3" "webhost" "192.168.16.4"

# deploys to server2
deploy "server2-mgmt" "webhost" "192.168.16.4" "loghost" "192.168.16.3"

# updates the local hosts file (makes configure-host executable as well)
chmod +x ./configure-host.sh
./configure-host.sh -hostentry loghost 192.168.16.3 $REMOTE_VERBOSE
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update local /etc/hosts for loghost"
    exit 1
fi

./configure-host.sh -hostentry webhost 192.168.16.4 $REMOTE_VERBOSE
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update local /etc/hosts for webhost"
    exit 1
fi

echo "Configuration complete."
exit 0
