#!/bin/bash

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.7.0\e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m VMware vSphere CSI and CPI Setup\e[0m'
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
export INSTALL_VSPHERE_CPI_DRIVER=true
export VSPHERE_CPI_TAG_CATEGORY_REGION="k8s-region"
export VSPHERE_CPI_TAG_CATEGORY_ZONE="k8s-zone"
export VSPHERE_CPI_TAG_REGION=""
export VSPHERE_CPI_TAG_ZONE=""
export VSPHERE_CPI_CREATE_TAGS="true"
export VSPHERE_CPI_CONFIG_FILE=""

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
        --install-vsphere-cpi-driver) INSTALL_VSPHERE_CPI_DRIVER="$2"; shift; shift;;        
        --vsphere-cpi-tag-category-region) VSPHERE_CPI_TAG_CATEGORY_REGION="$2"; shift; shift;;
        --vsphere-cpi-tag-category-zone) VSPHERE_CPI_TAG_CATEGORY_ZONE="$2"; shift; shift;;
        --vsphere-cpi-tag-region) VSPHERE_CPI_TAG_REGION="$2"; shift; shift;;
        --vsphere-cpi-tag-zone) VSPHERE_CPI_TAG_ZONE="$2"; shift; shift;;
        --vsphere-cpi-create-tags) VSPHERE_CPI_CREATE_TAGS="$2"; shift; shift;;
        --vsphere-cpi-config-file) VSPHERE_CPI_CONFIG_FILE="$2"; shift; shift;;
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

# Perform Validation
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export PARAM_CHECK_PASS=true
export PARAM_CHECK_WARN=false

if [[ ! -f "/etc/kubernetes/admin.conf" ]]; then
    echo -e "\e[31mError:\e[0m This script must be run on a Kubernetes master node. Please install Kubernetes first."
    PARAM_CHECK_PASS=false
fi

if [[ ! "$VCENTER_INSECURE" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-insecure\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m. (Default: \e[35mfalse\e[0m)"
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

if [[ -z "$VCENTER_DATACENTER_NAME" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vcenter-datacenter\e[0m is required! (Default: \e[35mDatacenter\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$VSPHERE_CSI_DRIVER_VERSION" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vsphere-csi-driver-version\e[0m is required! (Default: \e[35mlatest\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [[ -z "$STORAGE_CLASS_NAME_PREFIX" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--storage-class-name-prefix\e[0m is required! (Default: \e[35mvsphere-csi\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [[ ! -z "$VSPHERE_CPI_CONFIG_FILE" && ! -f "$VSPHERE_CPI_CONFIG_FILE" ]]; then
    echo -e "\e[31mError:\e[0m The file \e[35m$VSPHERE_CPI_CONFIG_FILE\e[0m specfied for \e[35m--vsphere-cpi-config-file\e[0m does not exist.\e[0m"
    PARAM_CHECK_PASS=false  
fi

if [[ ! "$INSTALL_VSPHERE_CPI_DRIVER" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--install-vsphere-cpi-driver\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m. (Default: \e[35mfalse\e[0m)"
    PARAM_CHECK_PASS=false
fi

if [[ ! "$VSPHERE_CPI_CREATE_TAGS" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--vsphere-cpi-create-tags\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m. (Default: \e[35mtrue\e[0m)"
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
    vm_id=$(govc vm.info -json "$myself" | jq -r ".virtualMachines[0].self.value" | tr -d '"')
    if [[ ! -z "$myself" ]]; then
        echo -e "Found myself at \033[35m$myself\033[0m (id: \033[35m$vm_id\033[0m) with IP address \033[35m$ip\033[0m"
        break
    fi
done

if [[ -z "$myself" ]]; then
    echo -e "\n\033[31mError:\e[0m I could not find myself in vSphere. Makes sure that I am actually running in vSphere and that the GOVC environment variables are correct." 
    echo -e "       This will likely result in the CSI driver not functioning correctly!"
    exit 1
fi

declare -A myTags

tags_json=$(govc tags.ls -json)
tag_count=$(echo "$tags_json" | jq '. | length')

for ((i=0; i<tag_count; i++)); do
  tag_id=$(echo "$tags_json" | jq -r ".[$i].id")
  tag_name=$(echo "$tags_json" | jq -r ".[$i].name")
  tag_category=$(echo "$tags_json" | jq -r ".[$i].category_id")  
  vm_tag_index=$(govc tags.attached.ls -json "$tag_id" | jq ". | index(\"VirtualMachine:$vm_id\")")
  if [[ $vm_tag_index != "null" ]]; then
    echo -e "Found tag: \033[35m$tag_category\033[0m = \033[34m$tag_name\033[0m"
    myTags["$tag_category"]="$tag_name"
  fi
done

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

# Search for datastore info

echo -e "\n\033[36mSearch for datastore(s)\033[0m"

export autoDetectDatastores=false

if [[ -z "$VCENTER_DATASTORES" ]]; then  
  echo -e "No datastores specified, listing all datastores in datacenter '$VCENTER_DATACENTER_NAME'.\n"
  autoDetectDatastores=true
  VCENTER_DATASTORES=$(govc ls /$VCENTER_DATACENTER_NAME/datastore | sed "s|^/$VCENTER_DATACENTER_NAME/datastore/||" | tr '\n' ',' | sed 's/,$//')
fi

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

if [[ $autoDetectDatastores == true ]]; then
  echo -e "\033[32mDiscovered ${#storageClasses[@]} datastore(s).\033[0m"
else
  echo -e "\033[32mSuccessfully found ${#storageClasses[@]} of ${#datastores[@]} datastore(s).\033[0m"
fi

# Install VMware CSI driver Helm chart
# https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/3.0/vmware-vsphere-csp-getting-started/GUID-A1982536-F741-4614-A6F2-ADEE21AA4588.html

echo -e "\n\033[36mInstall vSphere CSI driver\033[0m"

if [ $VSPHERE_CSI_DRIVER_VERSION == "latest" ]; then
  VSPHERE_CSI_DRIVER_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/vsphere-csi-driver/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')
  echo "Detected latest CSI driver version: $VSPHERE_CSI_DRIVER_VERSION\n"
fi

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
kubectl scale deploy vsphere-csi-controller --replicas=1 -n vmware-system-csi
kubectl create secret generic vsphere-config-secret --from-file=$CSI_VSPHERE_CONF --namespace=$VMWARE_CSI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

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

# Install VMware vSphere CPI Driver
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
      echo -e "\n\e[33mWarning:\e[0m This virtual machine has a \e[35m$category\e[0m tag but it is not the requested one."      
    fi    
  }

  if [[ $cat_test != 0 ]]; then
    if [[ "$VSPHERE_CPI_CREATE_TAGS" == true && ! -z "$tag" ]]; then
      echo -e "\nCreating tag category \033[35m$category\033[0m"
      cat_create_result=$(govc tags.category.create -d "Kubernetes tag category created by AutoK8s" "$category" 2>&1)
      if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError:\033[0m Failed to create tag category \033[35m$category\033[0m."
        echo -e "       $cat_create_result"
        show_warning
        return 0
      fi     
      echo -e "\033[32mSuccess!\033[0m"    
    else    
      echo -e "\033[33mTag category does not exist in vSphere. Ignoring.\033[0m"
      return 1
    fi
  fi

  if [[ -z "$tag" ]]; then
    echo -e "\033[32mTag category found!\033[0m"
    show_warning
    return 0
  fi
  
  tag_data=$(govc tags.info -json "$tag" 2>/dev/null | jq -r ".[] | select(.category_id==\"$category\")" 2>&1)
  
  if [[ $? -ne 0 || -z "$tag_data" || "$tag_data" =~ "not found" ]]; then
    tag_exists=false
  else
    tag_exists=true
  fi  

  if [[ $tag_exists == false ]]; then
    if [[ "$VSPHERE_CPI_CREATE_TAGS" == true ]]; then
      echo -e "\nCreating tag \033[34m$tag\033[0m"
      tag_create_result=$(govc tags.create -d "Kubernetes tag created by AutoK8s" -c "$category" "$tag" 2>&1)
      if [[ $? -ne 0 ]]; then
        echo -e "\033[31mError:\033[0m Failed to create tag \033[34m$tag\033[0m in category \033[35m$category\033[0m."
        echo -e "       $tag_create_result"
        show_warning
        return 0
      fi
      echo -e "\033[32mSuccess!\033[0m"
    else      
      tag_category=$(govc tags.info -json "$tag" 2>/dev/null | jq ".[].category_id" | tr '\n' ', ' | tr -d '" ' | sed 's/.$//')
      if [[ ! -z "$tag_category" && "$tag_category" != "$category" ]]; then 
        echo -e "\033[33mThe tag was found belonging to the category(s): \033[35m$tag_category\033[0m!\033[0m"
        show_warning 
        return 0
      else
        echo -e "\033[33mTag category found but tag does not exist in vSphere!\033[0m"
        show_warning
        return 0
      fi
    fi
  fi

  if [[ ! -z "$currentTag" && "$currentTag" != "$tag" ]]; then
    echo -e "\nRemoving tag \033[34m$currentTag\033[0m"
    currentTagId=$(govc tags.info -json "$currentTag" | jq -r ".[] | select(.category_id==\"$category\").id" 2>&1)
    tag_remove_result=$(govc tags.detach "$currentTagId" "$myself" 2>&1)
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
  
  tag_add_result=$(govc tags.attach -c "$category" "$tag" "$myself" 2>&1)
  
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

if [[ $INSTALL_VSPHERE_CPI_DRIVER == true ]]; then 
  echo -e "\033[36mInstall VMware CPI driver\033[0m"

  # Create vSphere cloud configmap and secret  

  if [[ -z "$VSPHERE_CPI_CONFIG_FILE" ]]; then
    echo -e "\n\033[36mGenerate vSphere config\033[0m"

    export VMWARE_SECRET_NAME="vsphere-cloud-secret"
    export VMWARE_CPI_NAMESPACE="vmware-system-cpi"
    export SECRET_FILE="$VMWARE_SECRET_NAME.yaml"
    export CONFIGMAP_FILE="vsphere-cloud-config.yaml"

    export VSPHERE_CONF="
global:
  port: 443  
  insecureFlag: $VCENTER_INSECURE  
  secretName: $VMWARE_SECRET_NAME
  secretNamespace: $VMWARE_CPI_NAMESPACE
vcenter:
  $VCENTER_ADDR:
    server: $VCENTER_ADDR
    datacenters:
      - $VCENTER_DATACENTER_NAME
labels: {}
"
    
    if [[ ! -z "$VSPHERE_CPI_TAG_CATEGORY_REGION" ]]; then
      check_tag "$VSPHERE_CPI_TAG_CATEGORY_REGION" "$VSPHERE_CPI_TAG_REGION"
      if [ $? -eq 0 ]; then
        VSPHERE_CONF=$(printf "%s\n" "$VSPHERE_CONF" | yq -y ".labels += { \"region\": \"$VSPHERE_CPI_TAG_CATEGORY_REGION\" }")
      fi
    fi

    if [[ ! -z "$VSPHERE_CPI_TAG_CATEGORY_ZONE" ]]; then
      check_tag "$VSPHERE_CPI_TAG_CATEGORY_ZONE" "$VSPHERE_CPI_TAG_ZONE"
      if [ $? -eq 0 ]; then
        VSPHERE_CONF=$(printf "%s\n" "$VSPHERE_CONF" | yq -y ".labels += { \"zone\": \"$VSPHERE_CPI_TAG_CATEGORY_ZONE\" }")
      fi
    fi
  else
    echo -e "\nUsing provided vSphere CPI config file: \033[35m$VSPHERE_CPI_CONFIG_FILE\033[0m"
    VSPHERE_CONF=$(cat $VSPHERE_CPI_CONFIG_FILE)
  fi

  echo -e "\n\033[36mCreate vSphere cloud configmap and secret\033[0m"

  cat <<EOF > $SECRET_FILE
apiVersion: v1
kind: Secret
metadata:
  name: $VMWARE_SECRET_NAME
  namespace: $VMWARE_CPI_NAMESPACE
stringData:
  $VCENTER_ADDR.username: $VCENTER_USERNAME
  $VCENTER_ADDR.password: $VCENTER_PASSWORD
EOF

  cat <<EOF > $CONFIGMAP_FILE
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-config
  namespace: $VMWARE_CPI_NAMESPACE
data:
  vsphere.conf: >
$(echo "$VSPHERE_CONF" | sed 's/^/    /')
EOF

  kubectl create namespace $VMWARE_CPI_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

  kubectl apply -f $CONFIGMAP_FILE && rm $CONFIGMAP_FILE
  kubectl apply -f $SECRET_FILE && rm $SECRET_FILE

  # Install CPI driver Helm chart
  # https://cloud-provider-vsphere.sigs.k8s.io/tutorials/kubernetes-on-vsphere-with-kubeadm

  echo -e "\n\033[36mInstall vSphere CPI driver Helm chart\033[0m"

  helm repo add vsphere-cpi https://kubernetes.github.io/cloud-provider-vsphere
  helm repo update
  helm upgrade --install vsphere-cpi vsphere-cpi/vsphere-cpi --namespace $VMWARE_CPI_NAMESPACE --wait

  echo -e "\n\033[36mTaint all nodes\033[0m"

  # Restart CPI pods and taint all nodes

  # Nodes need to be tainted in order for the CPI driver to complete the node registration. 
  # Taints are removed by the CPI driver once the nodes are registered.

  kubectl rollout restart daemonset/vsphere-cpi -n $VMWARE_CPI_NAMESPACE
  kubectl taint nodes --all node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule --overwrite
fi

echo -e "\n\033[32mInstallation Complete!\n\033[0m"
