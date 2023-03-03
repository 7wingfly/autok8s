#!/bin/bash

# Define variables

# ------------------------------
# Host TCP/IP Settings
# ------------------------------
# WARNING: If this is enabled and the IP address will be changed, make sure you are not running this script from a remote shell.
# 
export interface="ens160"
export ipAddress="192.168.0.10"
export netmask="255.255.255.0"
export defaultGateway="192.168.0.1"
export dnsServers=("192.168.0.2" "8.8.8.8")
export dnsSearch=("domain.local")

# Check sudo & keep sudo running

echo -e "\033[32mChecking root access\033[0m"

if [ "$(id -u)" -ne 0 ]
then
  echo -e "\033[31mYou must run this script as root\033[0m"
  exit
fi

# Configure IP Settings

echo -e "\033[32mConfiguring Network Settings\033[0m"

cat <<EOF | sudo tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: false
      dhcp6: false
      addresses: [$ipAddress/24]
      routes:
      - to: default
        via: $defaultGateway
      nameservers:
        search: [$(echo "${dnsSearch[@]}" | tr ' ' ',')]          
        addresses: [$(echo "${dnsServers[@]}" | tr ' ' ',')]
EOF

sudo netplan apply

echo -e "\033[32mComplete\033[0m"