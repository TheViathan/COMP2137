#!/bin/bash

# Ignore termination signals
trap 'echo "BUSY - DO NOT TERMINATE OR PAUSE THIS SCRIPT!"' TERM HUP INT

# Variables
VERBOSE=false
HOSTNAME_UPDATE=false
IP_UPDATE=false
HOSTENTRY_UPDATE=false

# Functions

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# logging function, automatically outputs in shell if VERBOSE
log_message() {
    local MESSAGE="$1"
    logger -t configure-host "$MESSAGE"
    if $VERBOSE; then
        echo "$MESSAGE"
    fi
}

# updates hostname in both hostname and hosts files
update_hostname() {
    local NEW_NAME="$1"
    local CURRENT_NAME=$(hostname)

    if [ "$CURRENT_NAME" != "$NEW_NAME" ]; then
        echo "$NEW_NAME" > /etc/hostname
        sudo hostnamectl set-hostname "$NEW_NAME"
        sed -i "s/$CURRENT_NAME$/$NEW_NAME/" /etc/hosts
        log_message "Hostname changed from $CURRENT_NAME to $NEW_NAME"
    elif $VERBOSE; then
        echo "Hostname is already set to $NEW_NAME"
    fi
}

# updates ip in both netplan and hosts files
update_ip() {
    local NEW_IP="$1"
    local CURRENT_IP=$(hostname -I | awk '{print $1}')
    local NETPLAN_FILE=$(find /etc/netplan -type f -name "*.yaml" | head -n 1)

    if [ -z "$NETPLAN_FILE" ]; then
        echo "No Netplan confissh "remoteadmin@$SERVER" --guration file found." >&2
        exit 1
    fi

    if [ "$CURRENT_IP" != "$NEW_IP" ]; then
        sudo sed -i "s/$CURRENT_IP/$NEW_IP/g" "$NETPLAN_FILE"
        sudo netplan apply
        log_message "IP address changed from $CURRENT_IP to $NEW_IP in $NETPLAN_FILE"

        sudo sed -i "s/$CURRENT_IP/$NEW_IP/g" /etc/hosts
    elif $VERBOSE; then
        echo "IP address is already set to $NEW_IP"
    fi
}

# updates a host entry in the hosts file
update_hosts_entry() {
    local ENTRY_NAME="$1"
    local ENTRY_IP="$2"

    if grep -q "$ENTRY_IP $ENTRY_NAME" /etc/hosts; then
        if $VERBOSE; then
            echo "Host entry $ENTRY_IP $ENTRY_NAME already exists in /etc/hosts"
        fi
    else
        echo "$ENTRY_IP $ENTRY_NAME" >> /etc/hosts
        log_message "Added host entry $ENTRY_IP $ENTRY_NAME to /etc/hosts"
    fi
}

# parses argument from the command line
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            shift
            ;;
        -name)
            HOSTNAME_UPDATE=true
            HOSTNAME_VALUE="$2"
            shift 2
            ;;
        -ip)
            IP_UPDATE=true
            IP_VALUE="$2"
            shift 2
            ;;
        -hostentry)
            HOSTENTRY_UPDATE=true
            HOSTENTRY_NAME="$2"
            HOSTENTRY_IP="$3"
            shift 3
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# calls functions depending on parsed arguments
if [ "$HOSTNAME_UPDATE" = true ]; then
    update_hostname "$HOSTNAME_VALUE"
fi

if [ "$IP_UPDATE" = true ]; then
    update_ip "$IP_VALUE"
fi

if [ "$HOSTENTRY_UPDATE" = true ]; then
    update_hosts_entry "$HOSTENTRY_NAME" "$HOSTENTRY_IP"
fi

exit 0
