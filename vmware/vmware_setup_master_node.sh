#!/bin/bash
set -euo pipefail

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.6.1\e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m VMWare vSphere CSI and CPI Setup\e[0m'
echo -e '\e[35m                                 \e[36m Master Node Edition\e[0m\n'

# Define Variables, Default Values & Parameters 
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export VCENTER_ADDR=""
export VCENTER_PASSWORD=""
export VCENTER_USERNAME="administrator@vsphere.local"
export VCENTER_INSECURE=false
export VCENTER_DATACENTER_NAME="Datacenter"
export VCENTER_DATASTORES=""
export VCENTER_DATASTORES_DELIMITER=","
export VSPHERE_CSI_DRIVER_VERSION="latest"
export STORAGE_CLASS_NAME_PREFIX="vsphere-csi"

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
        --vcenter-datacenter) VCENTER_DATACENTER_NAME="$2"; shift; shift;;
        --vcenter-datastores) VCENTER_DATASTORES=($2); shift; shift;;
        --vcenter-datastores-delimiter) VCENTER_DATASTORES_DELIMITER=($2); shift; shift;;
        --vsphere-csi-driver-version) VSPHERE_CSI_DRIVER_VERSION="$2"; shift; shift;;
        --storage-class-name-prefix) STORAGE_CLASS_NAME_PREFIX="$2"; shift; shift;;
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

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

if [[ -z "$VCENTER_DATACENTER_NAME" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-datacenter\e[0m is required! (Default: 'Datacenter')"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_DATASTORES" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-datastores\e[0m is required!"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VCENTER_DATASTORES" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-datastores\e[0m is required! (Comma separated names of datastores)"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VSPHERE_CSI_DRIVER_VERSION" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vsphere-csi-driver-version\e[0m is required! (Default: latest)"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$STORAGE_CLASS_NAME_PREFIX" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--storage-class-name-prefix\e[0m is required! (Default: vsphere-csi)"
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

if [ $VSPHERE_CSI_DRIVER_VERSION == "latest" ]; then
  VSPHERE_CSI_DRIVER_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/vsphere-csi-driver/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')
  echo "Detected latest CSI driver version: $VSPHERE_CSI_DRIVER_VERSION"
fi

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

# Search for datastore info

echo -e "\n\033[36mSearch for datastore(s)\033[0m"

declare -A storageClasses

IFS=$VCENTER_DATASTORES_DELIMITER read -r -a datastores <<< "$VCENTER_DATASTORES"
for datastore in "${datastores[@]}"; do
    echo -e "Name: \033[35m$datastore\033[0m"
    datastorePath="/$VCENTER_DATACENTER_NAME/datastore/$datastore"
    datastoreInfo=$(govc datastore.info "$datastorePath")
    if [[ $? -ne 0 ]]; then
        echo -e "\033[33mERROR: Failed to find datastore $datastorePath.\033[0m\n"        
    else
        url=$(echo "$datastoreInfo" | grep 'URL:' | awk '{print $2}')
        capacity=$(echo "$datastoreInfo" | grep 'Capacity:' | awk '{print $2 " " $3}')
        free=$(echo "$datastoreInfo" | grep 'Free:' | awk '{print $2 " " $3}')        
        echo -e "Capacity: $capacity"
        echo -e "Free: $free"
        echo -e "URL: $url\n"
        storageClasses[$datastore]=$url        
    fi
done

if [ ${#storageClasses[@]} -eq 0 ]; then
    echo -e "\033[31mERROR: Could not find any of the specified datastores.\033[0m"
    echo -e "\033[31m       You will need to create your storage classes manually.\033[0m"
    exit 1
fi

echo -e "\033[32mSuccessfully found ${#storageClasses[@]} of ${#datastores[@]} datastore(s).\033[0m"

# Install VMWare CSI driver Helm chart
# https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/3.0/vmware-vsphere-csp-getting-started/GUID-A1982536-F741-4614-A6F2-ADEE21AA4588.html

echo -e "\n\033[36mInstall VMWare CSI driver\033[0m"

export VMWARE_CSI_NAMESPACE="vmware-system-csi"
export CSI_VSPHERE_CONF="csi-vsphere.conf"

cat <<EOF > $CSI_VSPHERE_CONF
[VirtualCenter "$VCENTER_ADDR"]
insecure-flag = "$VCENTER_INSECURE"
user = "$VCENTER_USERNAME"
password = "$VCENTER_PASSWORD"
datacenters = "$VCENTER_DATACENTER_NAME"
EOF

export KUBECONFIG="/etc/kubernetes/admin.conf"
export CSI_DRIVER_BASE_URL="https://raw.githubusercontent.com/kubernetes-sigs/vsphere-csi-driver/v$VSPHERE_CSI_DRIVER_VERSION/manifests/vanilla"

kubectl apply -f $CSI_DRIVER_BASE_URL/namespace.yaml
kubectl apply -f $CSI_DRIVER_BASE_URL/vsphere-csi-driver.yaml
kubectl create secret generic vsphere-config-secret --from-file=$CSI_VSPHERE_CONF --namespace=$VMWARE_CSI_NAMESPACE --dry-run -o yaml | kubectl apply -f -

rm $CSI_VSPHERE_CONF

# Create storage class(es)
# https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid-Integrated-Edition/1.13/tkgi/GUID-vsphere-cns-manual.html

convert_to_k8s_name() {    
    local lowercase=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    local sanitized=$(echo "$lowercase" | sed 's/[^a-z0-9.-]/-/g')
    sanitized=$(echo "$sanitized" | sed 's/^[^a-z0-9]*//')
    sanitized=$(echo "$sanitized" | sed 's/[^a-z0-9]*$//')
    echo "$sanitized"
}

echo -e "\n\033[36mCreate storage class(es)\033[0m"

for datastore in "${!storageClasses[@]}"; do
    url="${storageClasses[$datastore]}"
    k8s_name=$(convert_to_k8s_name "$datastore")
    storage_class_name="$STORAGE_CLASS_NAME_PREFIX-$k8s_name"
    yaml_file="vphereStorageClass-$storage_class_name.yaml"
    echo -e "Datastore: \033[35m$datastore\033[0m"
    echo -e "Storage Class Retain: $storage_class_name-retain"
    echo -e "Storage Class Delete: $storage_class_name-delete\n"
    cat <<EOF > $yaml_file
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $storage_class_name-retain
  annotations:
      storageclass.kubernetes.io/is-default-class: "false"
provisioner: csi.vsphere.vmware.com
allowVolumeExpansion: true
reclaimPolicy: Retain
parameters:
  datastoreurl: "$url"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $storage_class_name-delete
  annotations:
      storageclass.kubernetes.io/is-default-class: "false"
provisioner: csi.vsphere.vmware.com
allowVolumeExpansion: true
reclaimPolicy: Delete
parameters:
  datastoreurl: "$url"
EOF
    echo "Creating storage classes ..."
    kubectl apply -f $yaml_file -n $VMWARE_CSI_NAMESPACE
    rm $yaml_file
    if [[ $? -eq 0 ]]; then
        echo -e "\033[32mDone!\n\033[0m"
    else
        echo -e "\033[33mERROR: Failed to create storage class for $datastore.\033[0m\n"  
    fi
done


# Install VMWare CPI driver Helm chart

echo -e "\n\033[36mInstall VMWare CPI driver Helm chart\033[0m"

helm repo add vsphere-cpi https://kubernetes.github.io/cloud-provider-vsphere
helm repo update
helm upgrade --install vsphere-cpi vsphere-cpi/vsphere-cpi \
    --namespace kube-system \
    --set config.enabled=true \
    --set config.vcenter=$VCENTER_ADDR \
    --set config.username=$VCENTER_USERNAME \
    --set config.password=$VCENTER_PASSWORD \
    --set config.datacenter=$VCENTER_DATACENTER_NAME

echo -e "\033[32mInstallation Complete!\n\033[0m"
