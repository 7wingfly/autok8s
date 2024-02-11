#!/bin/bash

# Define Variables, Default Values & Parameters 
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export VCENTER_USERNAME="administrator@vsphere.local"
export VCENTER_INSECURE=false

# ------------------------------
# Parameters
# ------------------------------
#

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --vcenter-host) VCENTER_ADDR="$2"; shift; shift;;
        --vcenter-username) VCENTER_USERNAME="$2"; shift; shift;;
        --vcenter-password) VCENTER_PASSWORD="$2"; shift; shift;;
        --vcenter-insecure) VCENTER_INSECURE="$2"; shift; shift;;      
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

echo -e '\e[35m      _         _        \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___  \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / _ \| | | | __/ _ \ \e[36m| |/ / _ \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | || (_) |\e[36m|   < (_) \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/ \e[36m|_|\_\___/|___/ \e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m VMWare vSphere CSI and CPI Setup\e[0m'
echo -e '\e[35m                                 \e[36m Worker Node Edition\e[0m\n'

# Perform Validation
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export PARAM_CHECK_PASS=true

if [[ ! "$VCENTER_INSECURE" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-insecure\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_ADDR" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-host\e[0m is required!"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_USERNAME" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-username\e[0m is required! (Default: 'administrator@vsphere.local')"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_PASSWORD" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-password\e[0m is required!"
    PARAM_CHECK_PASS=false
fi

if [ $PARAM_CHECK_PASS == false ]; then
    exit 1
fi

# Check sudo & keep sudo running

echo -e "\033[36mChecking root access\033[0m"

if [ "$(id -u)" -ne 0 ]
then
  echo -e "\033[31mYou must run this script as root\033[0m"
  exit
fi

sudo -v
while true; do  
  sudo -nv; sleep 1m
  kill -0 $$ 2>/dev/null || exit
done &

# Prevent interactive needsrestart command

export NEEDSRESART_CONF="/etc/needrestart/needrestart.conf"

if [ -f $NEEDSRESART_CONF ]; then 
  echo -e "\033[36mDisabling needsrestart interactive mode\033[0m"  
  sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" $NEEDSRESART_CONF
fi

# Install jq

echo -e "\n\033[36mInstall jq\033[0m"

which jq 1>/dev/null 2>/dev/null
if [ $? -ne 0 ]; then    
    apt-get update -q
    apt-get install jq -qqy    
    echo -e "\033[32mDone.\033[0m"
else
    echo "jq already installed"
fi

# Download and Install govc
# https://www.msystechnologies.com/blog/learn-how-to-install-configure-and-test-govc/

echo -e "\n\033[36mInstall and Configure govc\033[0m"

export GOVC_VERSION="v0.34.2"
export GOVC_VERSION_FILENAME="govc_Linux_x86_64.tar.gz"
export GOVC_DOWNLOAD_DIR="./govc"
export GOVC_DOWNLOAD_FILE="$GOVC_DOWNLOAD_DIR/$GOVC_VERSION_FILENAME"

which govc 1>/dev/null 2>/dev/null
if [ $? -ne 0 ]; then    
    mkdir -p $GOVC_DOWNLOAD_DIR
    wget -O $GOVC_DOWNLOAD_FILE https://github.com/vmware/govmomi/releases/download/$GOVC_VERSION/$GOVC_VERSION_FILENAME      
    tar -zxvf $GOVC_DOWNLOAD_FILE -C $GOVC_DOWNLOAD_DIR                
    sudo chmod +x $GOVC_DOWNLOAD_DIR/govc
    sudo cp $GOVC_DOWNLOAD_DIR/govc /usr/local/bin    
    rm -r $GOVC_DOWNLOAD_DIR
    echo -e "\033[32mDone.\033[0m"
else
    echo "govc already installed"
fi

export GOVC_URL="https://$VCENTER_ADDR"
export GOVC_USERNAME=$VCENTER_USERNAME
export GOVC_PASSWORD=$VCENTER_PASSWORD
export GOVC_INSECURE=$VCENTER_INSECURE

# Check user credentials and permissions

echo -e "\n\033[36mCheck vCenter access\033[0m"
echo -e "Username: \033[35m$VCENTER_USERNAME\033[0m"

echo "Checking authentication to vCenter ..."

user_credential_check=$(govc about 2>&1)

if [ $? -ne 0 ]; then    
    if echo "$user_credential_check" | grep -q "incorrect user name or password"; then
        echo -e "\033[31mERROR: The provided vcenter credentials are incorrect!\033[0m"
        echo -e "\033[31m       Please check the username and password then try again.\033[0m"                
    else
        echo -e "\033[31mERROR: An error occured while checking the credentials!\033[0m"
        echo -e "\033[31m       $user_credential_check\033[0m"
    fi
    exit 1
else
    echo -e "\033[32mAuthentication successful!\033[0m"    
fi

echo "Checking group membership ..."

user_details=$(govc sso.user.id $VCENTER_USERNAME 2>&1)

if [[ $? -eq 0 ]]; then
    groups=$(echo "$user_details" | grep -oP 'groups=\K[^ ]+')    
    IFS=',' read -ra group_array <<< "$groups"
    isadmin=false
    for group in "${group_array[@]}"; do        
        if [[ $group == "Administrators" ]]; then
            isadmin=true
            break
        fi
    done
    if [[ $isadmin == "true" ]]; then
        echo -e "\033[32mThe user is in the Administrators group!\033[0m"
    else
        echo -e "\033[33mWARNING: The user $VCENTER_USERNAME is not in the Administrators group!\033[0m"
        echo -e "\033[33m         Make sure that the user account has the required permissions / roles.\033[0m"
    fi
else
    echo -e "\033[33mWARNING: Could not confirm the group membership for user $VCENTER_USERNAME!\033[0m"
    echo -e "\033[33m         Make sure that the user account has the required permissions / roles.\033[0m"
    echo -e "\033[33m         $user_details\033[0m"
fi

echo -e "\n\033[36mUpdate VM settings in vSphere\033[0m"

echo "Searching for my own virtual machine in vSphere"

IP_ADDRESSES=$(hostname -I)

for ip in $IP_ADDRESSES; do
    myself=$(govc find / -type m -guest.ipAddress $ip)
    if [[ ! -z "$myself" ]]; then
        echo -e "Found myself at \033[35m$myself\033[0m"
        break
    fi
done

if [[ -z "$myself" ]]; then
    echo -e "\033[33mWARNING: I could not find myself in vSphere. Makes sure that I am actually running in vSphere and that the GOVC environment variables are correct.\033[0m" 
    echo -e "\033[33mThis will likely result in the CSI driver not functioning correctly!\033[0m"
else
    echo "Configuring disk.EnableUUID setting"
    enableUUID=$(govc vm.info -vm.ipath "$myself" -json  | jq -r '.virtualMachines[].config.extraConfig[] | select(.key=="disk.EnableUUID").value')
    if [ "$enableUUID" = "TRUE" ]; then
        echo "disk.EnableUUID is already enabled"
    else
        govc vm.change -vm "$myself" -e="disk.EnableUUID=TRUE"
        if [[ $? -ne 0 ]]; then
            echo -e "\033[31mError: Failed to configure disk.EnableUUID setting.\033[0m"
            echo -e "\033[31m       Please set this manually via the vSphere client.\033[0m"
        else
            echo -e "\033[32mSuccessfully configured disk.EnableUUID setting.\033[0m"
        fi
    fi
fi

echo -e "\033[32\nmSetup Complete!\n\033[0m"