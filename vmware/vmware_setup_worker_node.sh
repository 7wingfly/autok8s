#!/bin/bash

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.7.0\e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m VMWare vSphere CSI and CPI Setup\e[0m'
echo -e '\e[35m                                 \e[36m Worker Node Edition\e[0m\n'

# Define Variables, Default Values & Parameters 
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export VCENTER_ADDR=""
export VCENTER_PASSWORD=""
export VCENTER_USERNAME="administrator@vsphere.local"
export VCENTER_INSECURE=false
export MANAGE_TAGS_FOR_VSPHERE_CPI=false
export VSPHERE_CPI_TAG_CATEGORY_REGION="k8s-region"
export VSPHERE_CPI_TAG_CATEGORY_ZONE="k8s-zone"
export VSPHERE_CPI_TAG_REGION=""
export VSPHERE_CPI_TAG_ZONE=""

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
        --manage-tags-for-vsphere-cpi) MANAGE_TAGS_FOR_VSPHERE_CPI="$2"; shift; shift;;
        --vsphere-cpi-tag-category-region) VSPHERE_CPI_TAG_CATEGORY_REGION="$2"; shift; shift;;
        --vsphere-cpi-tag-category-zone) VSPHERE_CPI_TAG_CATEGORY_ZONE="$2"; shift; shift;;
        --vsphere-cpi-tag-region) VSPHERE_CPI_TAG_REGION="$2"; shift; shift;;
        --vsphere-cpi-tag-zone) VSPHERE_CPI_TAG_ZONE="$2"; shift; shift;;
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

# Perform Validation
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export PARAM_CHECK_PASS=true
export PARAM_CHECK_WARN=false

if [[ -f "/etc/kubernetes/admin.conf" || ! -f "/etc/kubernetes/kubelet.conf" ]]; then
    echo -e "\e[31mError:\e[0m This script must be run on a Kubernetes worker node. Please install Kubernetes first."
    PARAM_CHECK_PASS=false
fi

if [[ ! "$VCENTER_INSECURE" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-insecure\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_ADDR" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-host\e[0m is required!"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_USERNAME" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-username\e[0m is required! (Default: \e[35madministrator@vsphere.local\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_PASSWORD" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-password\e[0m is required!"
    PARAM_CHECK_PASS=false
fi

if [[ ! "$MANAGE_TAGS_FOR_VSPHERE_CPI" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--manage-tags-for-vsphere-cpi\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
    PARAM_CHECK_PASS=false
fi

if [[ ! -z "$VSPHERE_CPI_TAG_CATEGORY_REGION" && "$VSPHERE_CPI_TAG_CATEGORY_REGION" == *[!a-zA-Z0-9_-]* ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vsphere-cpi-tag-category-region\e[0m can only contain letters, numbers, dashes and underscores. (Default: \e[35mk8s-region\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [[ ! -z "$VSPHERE_CPI_TAG_CATEGORY_ZONE" && "$VSPHERE_CPI_TAG_CATEGORY_ZONE" == *[!a-zA-Z0-9_-]* ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vsphere-cpi-tag-category-zone\e[0m can only contain letters, numbers, dashes and underscores. (Default: \e[35mk8s-zone\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [ $PARAM_CHECK_PASS == false ]; then
    exit 1
fi

if [ $PARAM_CHECK_WARN == true ]; then
    sleep 10
fi

# Install VMware vSphere CSI Driver
# --------------------------------------------------------------------------------------------------------------------------------------------------------

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

export APT_LOCK="-o DPkg::Lock::Timeout=600"

# Install jq & yq

echo -e "\n\033[36mInstall jq & yq\033[0m"

apt-get update -qq $APT_LOCK
apt-get install jq yq -qqy $APT_LOCK

echo -e "\033[32mDone.\033[0m"

# Download and Install govc
# https://www.msystechnologies.com/blog/learn-how-to-install-configure-and-test-govc/

echo -e "\n\033[36mInstall and Configure govc\033[0m"

if [[ ! -f "/usr/local/bin/govc" ]]; then    
    curl -L -o - "https://github.com/vmware/govmomi/releases/latest/download/govc_$(uname -s)_$(uname -m).tar.gz" | tar -C /usr/local/bin -xvzf - govc
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

echo -e "\nChecking authentication to vCenter ..."

user_credential_check=$(govc session.login 2>&1)

if [ $? -ne 0 ]; then
    if [[ "$user_credential_check" =~ (incorrect user name or password)|(Invalid credentials) ]]; then
        echo -e "\n\033[31mError:\033[0m The provided vcenter credentials are incorrect!"
        echo -e "       Please check the username and password then try again."
    else
        echo -e "\n\033[31mError:\033[0m An error occured while checking the credentials!"
        echo -e "       $user_credential_check"
    fi
    exit 1
else
    echo -e "\033[32mAuthentication successful!\033[0m"    
fi

echo -e "\nChecking group membership ..."

export user_details=$(govc sso.user.id $VCENTER_USERNAME 2>&1)
export required_group="Administrators"

if [[ $? -eq 0 ]]; then
    groups=$(echo "$user_details" | grep -oP 'groups=\K[^ ]+')    
    IFS=',' read -ra group_array <<< "$groups"
    isadmin=false
    for group in "${group_array[@]}"; do        
        if [[ $group == $required_group ]]; then
            isadmin=true
            break
        fi
    done
    if [[ $isadmin == "true" ]]; then
        echo -e "\033[32mThe user is in the $required_group group!\033[0m"
    else
        echo -e "\n\033[33mWarning:\033[0m The user \033[35m$VCENTER_USERNAME\033[0m is not in the \033[35m$required_group\033[0m group!"
        echo -e "         Make sure that the user account has the required permissions / roles."
    fi
else
    echo -e "\n\033[33mWarning:\033[0m Could not confirm the group membership for user \033[35m$VCENTER_USERNAME\033[0m!"
    echo -e "         Make sure that the user account has the required permissions / roles."
    echo -e "         $user_details"
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
    echo -e "\n\033[31mError:\e[0m I could not find myself in vSphere. Makes sure that I am actually running in vSphere and that the GOVC environment variables are correct." 
    echo -e "       This will likely result in the CSI driver not functioning correctly!"
    exit 1
fi

declare -A myTags

while IFS= read -r tag; do
    tagCategory=$(govc tags.info -json "$tag" | jq -r '.[0].category_id')
    echo -e "Found tag: \033[35m$tagCategory\033[0m = \033[34m$tag\033[0m"
    myTags["$tagCategory"]="$tag"
done < <(govc tags.attached.ls -r "$myself")

echo -e "\nConfiguring \033[35mdisk.EnableUUID\033[0m setting"
enableUUID=$(govc vm.info -vm.ipath "$myself" -json  | jq -r '.virtualMachines[].config.extraConfig[] | select(.key=="disk.EnableUUID").value')

if [ "$enableUUID" = "TRUE" ]; then
    echo -e "\033[32mSetting is already enabled.\033[0m"
else
    govc vm.change -vm "$myself" -e="disk.EnableUUID=TRUE"
    if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError:\033[0m Failed to configure disk.EnableUUID setting."
        echo -e "       Please set this manually via the vSphere client."
    else
        echo -e "\033[32mSuccessfully configured disk.EnableUUID setting.\033[0m"
    fi
fi

# Configure tags for VMware vSphere CPI Driver
# --------------------------------------------------------------------------------------------------------------------------------------------------------

function check_tag() {
  category=$1
  tag=$2

  currentTag="${myTags[$category]}"

  if [[ ! -z "$tag" ]]; then
    tagmsg="and tag \033[34m$tag\033[0m"
  else
    tagmsg=""
  fi
  echo -e "\nChecking tag category \033[35m$category\033[0m $tagmsg"

  if [[ ! -z "$currentTag" && "$currentTag" == "$tag" ]]; then
    echo -e "\033[32mTag already set!\033[0m"
    return 0
  fi

  if [[ -z "$tag" && -v myTags[$category] ]]; then
    echo -e "\033[32mFound tag \033[34m$currentTag\033[0m!\033[0m"
    return 0
  fi

  cat_test=$(govc tags.category.info "$category" >/dev/null 2>&1; echo $?)  

  function show_warning() {
    if [[ ! -v myTags[$category] ]]; then
      echo -e "\n\e[33mWarning:\e[0m This virtual machine does not have a \e[35m$category\e[0m tag."
      echo -e "         The CPI driver will not remove the taint until one has been added."  
    else
      echo -e "\n\e[33mWarning:\e[0m This virtual machine has a \e[35m$category\e[0m tag but it is not the request one."      
    fi    
  }

  if [[ $cat_test != 0 ]]; then
    echo -e "\033[33mTag category does not exist in vSphere. Ignoring.\033[0m"
    return 1
  fi

  if [[ -z "$tag" ]]; then
    echo -e "\033[32mTag category found!\033[0m"
    show_warning
    return 0
  fi

  tag_test=$(govc tags.info "$tag" >/dev/null 2>&1; echo $?)
  
  if [[ $tag_test != 0 ]]; then
    echo -e "\033[33mTag category found but tag does not exist in vSphere!\033[0m"
    show_warning
    return 0
  fi

  if [[ $(govc tags.ls | grep $tag | awk '{print $2}') != $category ]]; then
    echo -e "\033[33mThe tag does not belong to the specified category!\033[0m"
    show_warning
    return 0
  fi

  if [[ ! -z "$currentTag" && "$currentTag" != "$tag" ]]; then
    echo -e "\nRemoving tag \033[34m$currentTag\033[0m"    
    tag_remove_result=$(govc tags.detach "$currentTag" "$myself" 2>&1)
    if [ $? -ne 0 ]; then
      echo -e "\n\033[31mError:\033[0m Failed to remove tag \033[34m$currentTag\033[0m from myself."
      echo -e "       $tag_remove_result"
      show_warning
      return 0
    else
      echo -e "\033[32mSuccess!\033[0m"
    fi
  fi

  echo -e "\nAdding tag \033[34m$tag\033[0m"
  
  tag_add_result=$(govc tags.attach "$tag" "$myself" 2>&1)
  
  if [ $? -ne 0 ]; then
    echo -e "\n\033[31mError:\033[0m Failed to add tag \033[34m$tag\033[0m to myself."
    echo -e "       $tag_add_result"
    show_warning
    return 0
  else
    echo -e "\033[32mSuccess!\033[0m"
  fi

  return 0
}

if [[ "$MANAGE_TAGS_FOR_VSPHERE_CPI" == true ]]; then
  echo -e "\n\033[36mCheck tags for VMWare CPI\033[0m"
      
  if [[ ! -z "$VSPHERE_CPI_TAG_CATEGORY_REGION" ]]; then
    check_tag "$VSPHERE_CPI_TAG_CATEGORY_REGION" "$VSPHERE_CPI_TAG_REGION"
  fi

  if [[ ! -z "$VSPHERE_CPI_TAG_CATEGORY_ZONE" ]]; then
    check_tag "$VSPHERE_CPI_TAG_CATEGORY_ZONE" "$VSPHERE_CPI_TAG_ZONE"
  fi  
fi

echo -e "\n\033[32mInstallation Complete!\n\033[0m"
