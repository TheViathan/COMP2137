#!/bin/bash

# Function to print informative messages
info_message() {
    echo -e "\n-------- $1 --------"
}

# Function to print errors
error_message() {
    echo -e "\n*** ERROR: $1 ***"
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
    error_message "This script must be run as root."
    exit 1
fi

# Configure network settings in the netplan file
info_message "Configuring network settings"

# Finds netplan file
NETPLAN_FILE=$(find /etc/netplan -type f -name "*.yaml" | head -n 1)
if test -z "$NETPLAN_FILE"; then
    error_message "No netplan configuration file found."
    exit 1
fi

if grep -q "192.168.16.21" "$NETPLAN_FILE"; then
    echo "Network already configured."
else
    if ! sed -i '/eth0:/,/addresses:/s/addresses: \[.*\]/addresses: [192.168.16.21\/24]/' "$NETPLAN_FILE"; then
        error_message "Failed to update netplan configuration."
        exit 1
    fi
    if ! netplan apply; then
        error_message "Failed to apply netplan changes."
        exit 1
    fi
    echo "Network configuration updated."
fi

# Update /etc/hosts
info_message "Updating /etc/hosts"
if sed -i '/server1$/d' /etc/hosts; then
    echo "192.168.16.21 server1" >> /etc/hosts
    info_message "Success!"
else
    error_message "Failed to update /etc/hosts."
    exit 1
fi


# Install required software (apache2 and squid)
info_message "Installing required software"
if ! apt update || ! apt install -y apache2 squid; then
    error_message "Failed to install required software."
    exit 1
fi

# Runs the squid and apache2 services
info_message "Running services"
if ! systemctl enable --now apache2 squid; then
    error_message "Failed to start required services."
    exit 1
fi

# Creates users and sets up SSH keys
info_message "Configuring user accounts"
USER_LIST=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)
SUDO_USER="dennis"
AUTHORIZED_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for user in "${USER_LIST[@]}"; do
    if ! id "$user" &>/dev/null; then
        if ! useradd -m -s /bin/bash "$user"; then
            error_message "Failed to create user $user."
            exit 1
        fi
        echo "User $user created."
    else
        echo "User $user already exists."
    fi

    # Creates SSH directory (if it isnt already there) and updates file perms
    mkdir -p "/home/$user/.ssh"
    chown -R "$user:$user" "/home/$user"
    chmod 700 "/home/$user/.ssh"

    # Generates SSH keys if missing
    if [[ ! -f "/home/$user/.ssh/id_rsa" ]]; then
        if ! sudo -u "$user" ssh-keygen -t rsa -b 4096 -f "/home/$user/.ssh/id_rsa" -N ""; then
            error_message "Failed to generate RSA key for $user."
            exit 1
        fi
    fi
    if [[ ! -f "/home/$user/.ssh/id_ed25519" ]]; then
        if ! sudo -u "$user" ssh-keygen -t ed25519 -f "/home/$user/.ssh/id_ed25519" -N ""; then
            error_message "Failed to generate ED25519 key for $user."
            exit 1
        fi
    fi

    # Adds public keys to authorized_keys
    cat "/home/$user/.ssh/id_rsa.pub" "/home/$user/.ssh/id_ed25519.pub" > "/home/$user/.ssh/authorized_keys"
    chmod 600 "/home/$user/.ssh/authorized_keys"
    chown -R "$user:$user" "/home/$user/.ssh"

done

# Adds key for dennis
if ! grep -q "$AUTHORIZED_KEY" "/home/dennis/.ssh/authorized_keys"; then
    if ! echo "$AUTHORIZED_KEY" >> "/home/dennis/.ssh/authorized_keys"; then
        error_message "Failed to add additional SSH key for dennis."
        exit 1
    fi
fi

# Gives dennis sudo
if ! usermod -aG sudo "$SUDO_USER"; then
    error_message "Failed to add $SUDO_USER to sudo group."
    exit 1
fi

info_message "System configuration completed successfully."
