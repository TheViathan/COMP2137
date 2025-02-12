#!/bin/bash

# System Information
USERNAME=$(whoami)
DATE_TIME=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
OS=$(lsb_release -d | cut -f2-)
UPTIME=$(uptime -p)

# Hardware Information
CPU=$(lscpu | grep -m 1 'Model name' | awk -F: '{print $2}' | sed 's/^ *//')
RAM=$(free -h | awk '/^Mem:/ {print $2}')
DISKS=$(lshw -class disk |
awk -F': ' '/vendor:/ {vendor=$2} /product:/ {product=$2} /size:/ {size=$2; printf "%s %s %s", vendor, product, size}')
VIDEO=$(lspci | grep -i 'VGA' | cut -d ':' -f3 | sed 's/^ *//')

# Network Information
FQDN=$(hostname --fqdn)
HOST_IP=$(ip a | awk '/inet / && !/127.0.0.1/ {print $2; exit}' | cut -d'/' -f1)
GATEWAY=$(ip r | awk '/default/ {print $3; exit}')
DNS_SERVER=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | paste -s -d ',')

# System Status
LOGGED_USERS=$(who | awk '{print $1}' | sort -u | paste -s -d ',')
DISK_SPACE=$(df -h --output=target,avail | awk 'NR>1 {print $1 " " $2}')
PROCESS_COUNT=$(ps aux --no-heading | wc -l)
LOAD_AVG=$(uptime | awk -F 'load average: ' '{print $2}')
LISTENING_PORTS=$(ss -tuln | awk 'NR>1 {print $5}' | awk -F: '{if (NF>1) print $NF}' | sort -n | uniq | paste -sd ',')
UFW_STATUS=$(ufw status | grep -q "Status: active" && echo "enabled" || echo "disabled")

# Prints System Report
echo "System Report generated by $USERNAME, $DATE_TIME"
echo ""
echo "System Information"
echo "------------------"
echo "Hostname: $HOSTNAME"
echo "OS: $OS"
echo "Uptime: $UPTIME"
echo ""
echo "Hardware Information"
echo "--------------------"
echo "CPU: $CPU"
echo "RAM: $RAM"
echo "Disk(s): $DISKS"
echo "Video: $VIDEO"
echo ""
echo "Network Information"
echo "-------------------"
echo "FQDN: $FQDN"
echo "Host Address: $HOST_IP"
echo "Gateway IP: $GATEWAY"
echo "DNS Server: $DNS_SERVER"
echo ""
echo "System Status"
echo "-------------"
echo "Users Logged In: $LOGGED_USERS"
echo "Disk Space:"
echo "$DISK_SPACE"
echo "Process Count: $PROCESS_COUNT"
echo "Load Averages: $LOAD_AVG"
echo "Listening Network Ports: $LISTENING_PORTS"
echo "UFW Status: $UFW_STATUS"
