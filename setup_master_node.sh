#!/bin/bash
set -euo pipefail

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.4.0\e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m Control-Plane Edition\e[0m\n'

# Check sudo & keep sudo running
# --------------------------------------------------------------------------------------------------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[31mYou must run this script as root\033[0m"
  exit
fi

sudo -v
while true; do  
  sudo -nv; sleep 1m
  kill -0 $$ 2>/dev/null || exit
done &

# Define Variables, Default Values & Parameters 
# --------------------------------------------------------------------------------------------------------------------------------------------------------

# ------------------------------
# Host TCP/IP Settings
# ------------------------------
# These options configure the TCP/IP settings of this server. These options have been added for your convenience however, you may not want to
# do this if your settings are already configured. You will still need to specify this machines IP address though as it will be required by 
# other parts of the script.
#
# WARNING: If this is enabled and the IP address will be changed, make sure you are not running this script from a remote shell.
# 
export configureTCPIPSetting=false
export interface="eth0"                                     # Find with 'ip addr'
export ipAddress=""                                         # Require even if 'configureTCPIPSetting' is set to 'false'.
export netmask=""
export defaultGateway=""
export dnsServers=("8.8.8.8" "4.4.4.4")                     # Don't specify more than 3. K8s will only use the first three and throw errors.
export dnsSearch=("domain.local")                           # Your local DNS search domain if you have one.

# ------------------------------
# Kubernetes
# ------------------------------
#
export k8sVersion="latest"                                  # You can specify a specific version such as "1.25.0-00".
export k8sLoadBalancerIPRange=""                            # Either a range such as "192.168.0.100-192.168.0.150" or a CIDR (Add /32 for a single IP).
export k8sCNI="flannel"                                     # Choose a Kubernetes network plugin.
export k8sAllowMasterNodeSchedule=true                      # Disabling this is best practice however without it MetalLB cannot be deployed until a node is added.
export k8sKubeadmOptions=""                                 # Additional options you can pass into the kubeadm init command. 
export k8sKubeadmConfig=""                                  # Path to kubeadm config file. Cannot be used with 'k8sKubeadmOptions'.

# ------------------------------
# Kubernetes Storage Classes
# ------------------------------
# If the 'nfsInstallServer' or 'smbInstallServer' values are set to 'false' but the 'nfsServer' or 'smbServer' values are set to anything 
# other than this machines hostname, the CSI driver(s) will be installed and storage class(es) created and configured for the specifed server(s).
#
# WARNING: Using the master node as a storage server is not standard practice nor recommended. This option exists so that those who are new to k8s
# can quickly and easily try out Kubernetes features and applications that rely on persistent storage. Do not do this in a production environment.
#
export nfsInstallServer=true
export nfsServer=$HOSTNAME 
export nfsSharePath="/shares/nfs"                           # Local server only.
export nfsDefaultStorageClass=false

export smbInstallServer=true
export smbServer=$HOSTNAME
export smbSharePath="/shares/smb"                           # Local server only.
export smbShareName="persistentvolumes"
export smbUsername=$SUDO_USER
export smbPassword="password"
export smbDefaultStorageClass=false                          # Only one storage class should be set as default.

# ------------------------------
# Parameters
# ------------------------------
#
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --configure-tcpip) configureTCPIPSetting="$2"; shift; shift;;
        --interface) interface="$2"; shift; shift;;
        --ip-address) ipAddress="$2"; shift; shift;;
        --netmask) netmask="$2"; shift; shift;;
        --default-gateway) defaultGateway="$2"; shift; shift;;
        --dns-servers) dnsServers=($2); shift; shift;;
        --dns-search) dnsSearch=($2); shift; shift;;
        --k8s-version) k8sVersion="$2"; shift; shift;;
        --k8s-load-balancer-ip-range) k8sLoadBalancerIPRange="$2"; shift; shift;;
        --k8s-cni) k8sCNI="$2"; shift; shift;;
        --k8s-allow-master-node-schedule) k8sAllowMasterNodeSchedule="$2"; shift; shift;;
        --k8s-kubeadm-options) k8sKubeadmOptions="$2"; shift; shift;;
        --k8s-kubeadm-config) k8sKubeadmConfig="$2"; shift; shift;;
        --nfs-install-server) nfsInstallServer="$2"; shift; shift;;
        --nfs-server) nfsServer="$2"; shift; shift;;
        --nfs-share-path) nfsSharePath="$2"; shift; shift;;
        --nfs-default-storage-class) nfsDefaultStorageClass="$2"; shift; shift;;
        --smb-install-server) smbInstallServer="$2"; shift; shift;;
        --smb-server) smbServer="$2"; shift; shift;;
        --smb-share-path) smbSharePath="$2"; shift; shift;;
        --smb-share-name) smbShareName="$2"; shift; shift;;
        --smb-username) smbUsername="$2"; shift; shift;;
        --smb-password) smbPassword="$2"; shift; shift;;
        --smb-default-storage-class) smbDefaultStorageClass="$2"; shift; shift;;
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

# Perform Validation
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export HARDWARE_CHECK_PASS=true

export MIN_CPUS=2
export CPU_COUNT=$(grep -c "^processor" /proc/cpuinfo)
if [ $CPU_COUNT -lt $MIN_CPUS ]; then
    echo -e "\e[31mError:\e[0m The system must have at least \e[35m$MIN_CPUS\e[0m CPU's to run Kubernetes. You currently have \e[35m${CPU_COUNT}\e[0m."
    HARDWARE_CHECK_PASS=false
else
    echo -e "\e[32mInfo:\e[0m The system has \e[35m$CPU_COUNT\e[0m CPU's."
fi

export MIN_RAM=1700
export RAM_TOTAL=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
export RAM_MB=$((RAM_TOTAL / 1024))
if [ $RAM_MB -lt $MIN_RAM ]; then
    echo -e "\e[31mError:\e[0m The system must have at least \e[35m${MIN_RAM} MB\e[0m of memory to run Kubernetes. You currently have \e[35m${RAM_MB} MB\e[0m."
    HARDWARE_CHECK_PASS=false
else
    echo -e "\e[32mInfo:\e[0m The system has \e[35m${RAM_MB} MB\e[0m of memory."
fi

if [ $HARDWARE_CHECK_PASS == false ]; then
  exit 1
fi

export PARAM_CHECK_PASS=true
export PARAM_CHECK_WARN=false

# Try and determine IP address if one is not specified

if [[ "$configureTCPIPSetting" == false ]]; then
  if [[ -z "$ipAddress" ]]; then
    eth_adapters=$(ip link | grep "state UP" | grep -v "lo:" | awk -F': ' '{print $2}')
    num_eth_adapters=$(echo $eth_adapters | wc -w)
    if [ $num_eth_adapters -eq 1 ]; then
        interface=$(echo $eth_adapters)
        export CIDR=$(ip addr show $eth_adapters | grep -E "inet .* $eth_adapters" | awk '{print $2}')
        ipAddress=$(echo $CIDR | cut -d "/" -f 1)
        echo -e "\e[32mInfo:\e[0m The system has IP address \e[35m$ipAddress\e[0m on interface \e[35m$interface\e[0m. This will be used for the Kubernetes server API advertise IP address."        
    else
        echo -e "\e[31mError:\e[0m This machine has more than one IP address. \e[35m--ip-address\e[0m is required."
        PARAM_CHECK_PASS=false
    fi  
  elif [[ ! -z "$ipAddress" && ! $ipAddress =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--ip-address\e[0m value \e[35m$ipAddress\e[0m is not a valid IP address."
    PARAM_CHECK_PASS=false
  fi
fi

if [[ ! "$configureTCPIPSetting" =~ ^(true|false)$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--configure-tcpip\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
  PARAM_CHECK_PASS=false
fi

if [[ ! "$k8sAllowMasterNodeSchedule" =~ ^(true|false)$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-allow-master-node-schedule\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
  PARAM_CHECK_PASS=false
elif [[ "$k8sAllowMasterNodeSchedule" == false ]]; then
  cnischedulewarn=""
  if [ $k8sCNI == "cilium" ]; then cnischedulewarn=" and some Cilium pods"; fi
  echo -e "\e[33mWarning:\e[0m Master (control-plane) node scheduling will not be enabled. This means that non-core pods will not be scheduled until a worker node is added to the cluster. This includes Metal LB$cnischedulewarn which will result in networking issues."
  PARAM_CHECK_WARN=true
fi

if [[ ! "$smbInstallServer" =~ ^(true|false)$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--configure-tcpip\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
  PARAM_CHECK_PASS=false
fi

if [[ "$configureTCPIPSetting" == true ]]; then
  if [[ -z "$interface" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--interface\e[0m is required when \e[35m--configure-tcpip\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$ipAddress" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--ip-address\e[0m is required when \e[35m--configure-tcpip\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false
  elif [[ ! $ipAddress =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--ip-address\e[0m value \e[35m$ipAddress\e[0m is not a valid IP address."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$netmask" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--netmask\e[0m is required when \e[35m--configure-tcpip\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false    
  elif [[ ! "$netmask" =~ ^(255|254|252|248|240|224|192|128|0)\.((255|254|252|248|240|224|192|128|0)\.){2}(255|254|252|248|240|224|192|128|0)$ ]]; then  
    echo -e "\e[31mError:\e[0m \e[35m--netmask\e[0m value \e[35m$netmask\e[0m is not a valid network mask."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$defaultGateway" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--default-gateway\e[0m is required when \e[35m--configure-tcpip\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false
  elif [[ ! $defaultGateway =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--default-gateway\e[0m value \e[35m$defaultGateway\e[0m is not a valid IP address."
    PARAM_CHECK_PASS=false
  fi
  if [[ "${#dnsServers[@]}" -gt 3 ]]; then
    echo -e "\e[33mWarning:\e[0m Number of DNS servers should not be greater than 3. Kubernetes may display errors but will continue to work."
    PARAM_CHECK_WARN=true
  fi
  for ip in "${dnsServers[@]}"; do
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo -e "\e[31mError:\e[0m DNS server \e[35m$ip\e[0m is not a valid IP address."
        PARAM_CHECK_PASS=false
    fi
  done
fi

if [[ ! $k8sVersion =~ ^(latest)$|^[0-9]{1,2}\.[0-9]{1,2}$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--k8s-version\e[0m value \e[35m$k8sVersion\e[0m is not in the correct format."
    PARAM_CHECK_PASS=false
fi

if [[ ! $k8sCNI =~ ^(flannel|cilium|none)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--k8s-cni\e[0m value \e[35m$k8sVersion\e[0m is not valid. Options are: flannel, none."
    PARAM_CHECK_PASS=false
fi

if [ $k8sCNI == "none" ]; then
  echo -e "\033[33mWarning:\033[0m You have chosen not to install a CNI. Your master node will not be in a 'ready' state until you install one."
  PARAM_CHECK_WARN=true
fi

if [[ "$k8sKubeadmOptions" =~ "--config" ]]; then
  echo -e "\e[31mError:\e[0m You cannot use the \e[35m--config\e[0m argument inside of \e[35m--k8s-kubeadm-options\e[0m. Instead use \e[35m--k8s-kubeadm-config <config file>\e[0m.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && ! -z "$k8sKubeadmOptions" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-kubeadm-options\e[0m and \e[35m--k8s-kubeadm-config\e[0m cannot be used at the same time.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && ! -f "$k8sKubeadmConfig" ]]; then
  echo -e "\e[31mError:\e[0m The file \e[35m$k8sKubeadmConfig\e[0m specfied for \e[35m--k8s-kubeadm-config\e[0m does not exist.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ -z "$k8sLoadBalancerIPRange" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-load-balancer-ip-range\e[0m is required. Must be a valid IP range or CIDR."
  PARAM_CHECK_PASS=false
elif [[ ! "$k8sLoadBalancerIPRange" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}-([0-9]{1,3}\.){3}[0-9]{1,3}$|^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-load-balancer-ip-range\e[0m range must be a valid IP range or CIDR."
  PARAM_CHECK_PASS=false
fi

if [[ ! "$nfsInstallServer" =~ ^(true|false)$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--nfs-install-server\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
  PARAM_CHECK_PASS=false
elif [[ "$nfsInstallServer" = true ]]; then
  if [[ -z "$nfsSharePath" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--nfs-share-path\e[0m is required if \e[35m--nfs-install-server\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false  
  elif [[ ! "$nfsSharePath" =~ ^\/(.+\/)*[^\/]+$ ]]; then  
    echo -e "\e[31mError:\e[0m \e[35m--nfs-share-path\e[0m value \e[35m$nfsSharePath\e[0m is not a valid path."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$nfsServer" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--nfs-server\e[0m is required if \e[35m--nfs-install-server\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false  
  fi
  if [[ ! "$nfsDefaultStorageClass" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--nfs-default-storage-class\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
    PARAM_CHECK_PASS=false
  fi
fi

if [[ -n "$nfsServer" && ! $nfsServer =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--nfs-server\e[0m value \e[35m$smbServer\e[0m is not a valid hostname."
  PARAM_CHECK_PASS=false
fi

if [[ ! "$smbInstallServer" =~ ^(true|false)$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--smb-install-server\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
  PARAM_CHECK_PASS=false
elif [[ "$smbInstallServer" = true ]]; then
  if [[ -z "$smbSharePath" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--smb-share-path\e[0m is required if \e[35m--smb-install-server\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false  
  elif [[ ! "$smbSharePath" =~ ^\/(.+\/)*[^\/]+$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--smb-share-path\e[0m value \e[35m$smbSharePath\e[0m is not a valid path."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$smbShareName" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--smb-share-name\e[0m is required if \e[35m--smb-install-server\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false
  elif [[ ! "$smbShareName" =~ ^[a-zA-Z0-9_\$\.\-]+$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--smb-share-name\e[0m value \e[35m$smbShareName\e[0m is not a SMB share name."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$smbServer" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--smb-server\e[0m is required if \e[35m--smb-install-server\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false  
  fi
  if [[ ! "$smbDefaultStorageClass" =~ ^(true|false)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--smb-default-storage-class\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
    PARAM_CHECK_PASS=false
  fi
fi

if [[ -n "$smbServer" && ! $smbServer =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--smb-server\e[0m value \e[35m$smbServer\e[0m is not a valid hostname."
  PARAM_CHECK_PASS=false
fi

if [[ "$nfsDefaultStorageClass" = true && "$smbDefaultStorageClass" = true ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--smb-default-storage-class\e[0m and \e[35m--nfs-default-storage-class\e[0m cannot both be set to true at the same time.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ "$nfsDefaultStorageClass" = false && "$smbDefaultStorageClass" = false ]]; then
  echo -e "\e[32mInfo:\e[0m The default storage class will be set to \e[35msmb\e[0m"
  smbDefaultStorageClass=true
fi

if [ $PARAM_CHECK_PASS == false ]; then
  exit 1
fi

if [ $PARAM_CHECK_WARN == true ]; then
  sleep 10
fi

# Install Kubernetes
# --------------------------------------------------------------------------------------------------------------------------------------------------------

# Prevent interactive needsrestart command

export NEEDSRESART_CONF="/etc/needrestart/needrestart.conf"

if [ -f $NEEDSRESART_CONF ]; then 
  echo -e "\033[32mDisabling needsrestart interactive mode\033[0m"  
  sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" $NEEDSRESART_CONF
fi

# Configure IP Settings

if [ "$configureTCPIPSetting" == true ]; then

  echo -e "\033[32mConfiguring Network Settings\033[0m"

  IFS=. read -r i1 i2 i3 i4 <<< "$ipAddress"
  IFS=. read -r m1 m2 m3 m4 <<< "$netmask"

  maskDec=$(( (m1 * 16777216) + (m2 * 65536) + (m3 * 256) + m4 ))
  maskBin=$(echo "obase=2; $maskDec" | bc)
  cidr=$(echo "$maskBin" | tr -d '\n' | sed 's/0*$//' | wc -c)

  cat <<EOF | tee /etc/netplan/01-netcfg.yaml > /dev/null
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: false
      dhcp6: false
      addresses: [$ipAddress/$cidr]
      routes:
      - to: default
        via: $defaultGateway
      nameservers:
        search: [$(echo "${dnsSearch[@]}" | tr ' ' ',')]
        addresses: [$(echo "${dnsServers[@]}" | tr ' ' ',')]
EOF

  netplan apply
fi

# Install Prerequsite Packages

echo -e "\033[32mInstalling prerequisites\033[0m"

sleep 1 # Sleep for a second in case of file locks

apt-get update -qq
apt-get install -qqy apt-transport-https ca-certificates curl software-properties-common gzip gnupg lsb-release

# Add Docker Repository https://docs.docker.com/engine/install/ubuntu/

export KEYRINGS_DIR="/etc/apt/keyrings"

if [ ! -d $KEYRINGS_DIR ]; then
  mkdir -m 0755 -p $KEYRINGS_DIR
fi

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  echo -e "\033[32mAdding Docker repository\033[0m"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o $KEYRINGS_DIR/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=$KEYRINGS_DIR/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# Install Docker https://docs.docker.com/engine/install/ubuntu/

echo -e "\033[32mInstalling Docker\033[0m"

sleep 1 # Sleep for a second in case of file locks

apt-get update -qq
apt-get install -qqy docker-ce docker-ce-cli

tee /etc/docker/daemon.json >/dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Replace default config file to enable CRI plugin and SystemdCgroup
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd
tee /etc/containerd/config.toml >/dev/null <<EOF
version = 2

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true
EOF

systemctl daemon-reload
systemctl restart docker
systemctl restart containerd

# Install Kubernetes https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

echo -e "\033[32mInstalling Kubernetes\033[0m"

# Discover latest kubernetes version

export K8S_LATEST_VERSION=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')

if [ $k8sVersion == "latest" ]; then
  k8sVersion=$K8S_LATEST_VERSION
  echo "Detected latest Kubernetes version: $k8sVersion"
fi

export K8S_REPO_VERSION="v$(echo "$k8sVersion" | cut -d. -f1,2)"

echo "Using APT repo: $K8S_REPO_VERSION"

# Add Kubernetes Respository

if [ -f /etc/apt/sources.list.d/kubernetes.list ]; then
  rm $KEYRINGS_DIR/kubernetes-apt-keyring.gpg
  rm /etc/apt/sources.list.d/kubernetes.list
fi

echo -e "\033[32mAdding Kubernetes community repository\033[0m"
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_REPO_VERSION/deb/Release.key | gpg --dearmor -o $KEYRINGS_DIR/kubernetes-apt-keyring.gpg    
echo "deb [signed-by=$KEYRINGS_DIR/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_REPO_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

sleep 1 # Sleep for a second in case of file locks

apt-get update -qq
apt-get install -qqy kubelet kubeadm kubectl

# Configuring Prerequisite

echo -e "\033[32mEnable IPv4 packet forwarding\033[0m"

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Some of this config was required for older versions of Kubernetes.
# See here: https://v1-28.docs.kubernetes.io/docs/setup/production-environment/container-runtimes/

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# Disabling Swap

echo -e "\033[32mDisabling Swapping\033[0m"

if grep -v '^#' /etc/fstab | grep -q swap; then
  export BACKUP_FSTAB="/etc/fstab.backup.$(date +%s)"

  cp /etc/fstab $BACKUP_FSTAB
  sed -i '/swap/ s/^/#/' /etc/fstab
  swapoff -a

  echo "The file /etc/fstab has been backed-up to $BACKUP_FSTAB"
  echo "Swap is now disabled"
else
  echo "Swap is already disabled"
fi

# Init Kubernetes https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/

echo -e "\033[32mInitilizing Kubernetes\033[0m"

if [[ -z "$k8sKubeadmConfig" ]]; then
  export KUBEADM_ARGS="--apiserver-advertise-address=$ipAddress --pod-network-cidr=10.244.0.0/16 $k8sKubeadmOptions"
else
  echo -e "\033[32mValidating kubeadm config file\033[0m"
  kubeadm config validate --config $k8sKubeadmConfig
  export KUBEADM_ARGS="--config $k8sKubeadmConfig"
fi

kubeadm init $KUBEADM_ARGS

# Setup kube config files.

echo -e "\033[32mSetting up kubectl config files\033[0m"

# Setup root user kubectl config file
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# Setup your user kubectl config file
mkdir -p /home/$SUDO_USER/.kube
cp -f /etc/kubernetes/admin.conf /home/$SUDO_USER/.kube/config 
chown $SUDO_USER /home/$SUDO_USER/.kube/config

# Remove control-plane node taints

export hostname_lower=$(echo $HOSTNAME | tr '[:upper:]' '[:lower:]')
export WAIT=""

if [ $k8sAllowMasterNodeSchedule == true ]; then
  echo -e "\033[32mRemoving NoSchedule taints\033[0m"

  kubectl taint node $hostname_lower node-role.kubernetes.io/control-plane:NoSchedule- || true
  kubectl taint node $hostname_lower node-role.kubernetes.io/master:NoSchedule- || true # for older versions
  WAIT="--wait"
fi

# Install a CNI

if [ $k8sCNI == "flannel" ]; then
  # Flannel https://github.com/flannel-io/flannel/#readme

  echo -e "\033[32mInstalling CNI: Flannel\033[0m"

  sysctl net.bridge.bridge-nf-call-iptables=1
  sysctl -p
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml $WAIT

elif [ $k8sCNI == "cilium" ]; then
  # Cilium https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/

  echo -e "\033[32mInstalling CNI: Cilium\033[0m"

  # Install Cilium CLI

  if [ ! -f /usr/local/bin/cilium ]; then  
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
    CLI_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
  fi

  # Install Hubble Client

  if [ ! -f /usr/local/bin/hubble ]; then
    HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
    HUBBLE_ARCH=amd64
    if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
    curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
    sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
    rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
  fi

  # Install Cilium

  cilium install || true

  # Enable Hubble & Hubble UI

  if ! kubectl get deployment -n kube-system hubble-relay &> /dev/null; then
    echo -e "\033[32mEnabling Hubble\033[0m"
    cilium hubble enable
  fi

  if ! kubectl get deployment -n kube-system hubble-ui &> /dev/null; then
    echo -e "\033[32mEnabling Hubble UI\033[0m"
    cilium hubble enable --ui
  fi

  # Get Cilium status (Not all pods start up unless taint is removed)
  
  if [ $k8sAllowMasterNodeSchedule == true ]; then
    cilium upgrade --reuse-values \
      --set hubble.relay.tolerations[0].key=node-role.kubernetes.io/control-plane \
      --set hubble.relay.tolerations[0].operator=Exists \
      --set hubble.relay.tolerations[0].effect=NoSchedule \
      --set hubble.relay.tolerations[1].key=node-role.kubernetes.io/master \
      --set hubble.relay.tolerations[1].operator=Exists \
      --set hubble.relay.tolerations[1].effect=NoSchedule \
      --set hubble.ui.tolerations[0].key=node-role.kubernetes.io/control-plane \
      --set hubble.ui.tolerations[0].operator=Exists \
      --set hubble.ui.tolerations[0].effect=NoSchedule \
      --set hubble.ui.tolerations[1].key=node-role.kubernetes.io/master \
      --set hubble.ui.tolerations[1].operator=Exists \
      --set hubble.ui.tolerations[1].effect=NoSchedule
  fi
  
  cilium status $WAIT  
fi

# Install Helm

echo -e "\033[32mInstalling Helm\033[0m"

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install NFS Server and/or CSI and Storage Classes https://github.com/kubernetes-csi/csi-driver-nfs

export INSTALL_NFS_DRIVER=false # Do not edit. Will be set to true if required

if [ $nfsInstallServer == true ]; then
  echo -e "\033[32mInstall NFS File Server\033[0m"

  apt install -qqy nfs-kernel-server
  export NFS_CONFIG_FILE="/etc/exports"  
  if ! grep -q "$nfsSharePath" "$NFS_CONFIG_FILE"; then
    mkdir -p $nfsSharePath
    chown -R nobody:nogroup $nfsSharePath
    cat << EOF >> $NFS_CONFIG_FILE
$nfsSharePath    *(rw,sync,no_subtree_check)
EOF
    systemctl restart nfs-kernel-server
    showmount -e
    export INSTALL_NFS_DRIVER=true
  fi
elif [ "$nfsServer" != "$HOSTNAME" ]; then
  echo -e "\033[32mCreating NFS storge class for server $nfsServer \033[0m"
  export INSTALL_NFS_DRIVER=true
fi

# Define annotations for CSI drivers based on CNI choice

export CSI_CNI_ANNOTATIONS=""

if [ $k8sCNI == "cilium" ]; then
  CSI_CNI_ANNOTATIONS="--set controller.podAnnotations.\"cilium\.io/unmanaged\"=\"true\" --set node.podAnnotations.\"cilium\.io/unmanaged\"=\"true\""
fi

# NFS CSI Driver https://github.com/kubernetes-csi/csi-driver-nfs/tree/master/charts

if [ $INSTALL_NFS_DRIVER == true ]; then
  echo -e "\033[32mInstall NFS CSI driver Helm chart\033[0m"

  export NFS_SERVER_NAME_SAFE=$(echo "$nfsServer" | tr '.' '-' | tr '[:upper:]' '[:lower:]')
  export NFS_NAME_SPACE="kube-system"    
  export NFS_STORAGE_CLASS_FILE="nfsStorageClass.yaml"
  helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
  helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace $NFS_NAME_SPACE $CSI_CNI_ANNOTATIONS
   
  # See this page for all available parameters https://github.com/kubernetes-csi/csi-driver-nfs/blob/master/docs/driver-parameters.md
  cat <<EOF > $NFS_STORAGE_CLASS_FILE
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-$NFS_SERVER_NAME_SAFE
  annotations:
    storageclass.kubernetes.io/is-default-class: "$nfsDefaultStorageClass"
provisioner: nfs.csi.k8s.io
parameters:
  server: $nfsServer
  share: $nfsSharePath
reclaimPolicy: Retain
volumeBindingMode: Immediate
mountOptions:
  - nfsvers=4.1
EOF
  kubectl apply -f $NFS_STORAGE_CLASS_FILE -n $NFS_NAME_SPACE
  rm $NFS_STORAGE_CLASS_FILE
fi

# Install SMB Server and/or CSI and Storage Classes https://ubuntu.com/tutorials/install-and-configure-samba#2-installing-samba

export INSTALL_SMB_DRIVER=false # Do not edit. Will be set to true if required

if [ $smbInstallServer == true ]; then
  echo -e "\033[32mInstall SMB File Server\033[0m"

  apt install -qqy samba
  export SMB_CONFIG_FILE="/etc/samba/smb.conf"  
  if ! grep -q "$smbShareName" "$SMB_CONFIG_FILE"; then
    mkdir -p $smbSharePath
    chown -R $smbUsername:$smbUsername $smbSharePath
    cat << EOF >> $SMB_CONFIG_FILE
[$smbShareName]
    comment = SMB Share for Kubernetes PVC's
    path = $smbSharePath
    read only = no
    browsable = yes
EOF
    (echo "$smbPassword"; echo "$smbPassword") | smbpasswd -s -a "$smbUsername"  
    service smbd restart
    export INSTALL_SMB_DRIVER=true
  fi
elif [ "$smbServer" != "$HOSTNAME" ]; then
  echo -e "\033[32mCreating SMB storge class for server $nfsServer \033[0m"
  export INSTALL_SMB_DRIVER=true
fi

# SMB CSI Driver https://github.com/kubernetes-csi/csi-driver-smb/tree/master/charts

if [ $INSTALL_SMB_DRIVER == true ]; then
  echo -e "\033[32mInstall SMB CSI driver Helm chart\033[0m"

  export SMB_SERVER_NAME_SAFE=$(echo "$smbServer" | tr '.' '-' | tr '[:upper:]' '[:lower:]')
  export SMB_NAME_SPACE="kube-system"
  export SMB_SECRET_NAME="smb-credentials-$SMB_SERVER_NAME_SAFE"  
  export SMB_STORAGE_CLASS_FILE="smbStorageClass.yaml"
  helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
  helm install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace $SMB_NAME_SPACE --set controller.runOnControlPlane=true $CSI_CNI_ANNOTATIONS
  kubectl create secret generic $SMB_SECRET_NAME --from-literal username="$smbUsername" --from-literal password="$smbPassword" -n $SMB_NAME_SPACE

  # See this page for all available parameters https://github.com/kubernetes-csi/csi-driver-smb/blob/master/docs/driver-parameters.md
  cat <<EOF > $SMB_STORAGE_CLASS_FILE
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: smb-$SMB_SERVER_NAME_SAFE
  annotations:
    storageclass.kubernetes.io/is-default-class: "$smbDefaultStorageClass"
provisioner: smb.csi.k8s.io
parameters:
  source: "//$smbServer/$smbShareName"
  csi.storage.k8s.io/node-stage-secret-name: $SMB_SECRET_NAME
  csi.storage.k8s.io/node-stage-secret-namespace: $SMB_NAME_SPACE
  csi.storage.k8s.io/provisioner-secret-name: $SMB_SECRET_NAME
  csi.storage.k8s.io/provisioner-secret-namespace: $SMB_NAME_SPACE
reclaimPolicy: Retain      # only Retain is supported
volumeBindingMode: Immediate
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1001
  - gid=1001
EOF
  kubectl apply -f $SMB_STORAGE_CLASS_FILE -n $SMB_NAME_SPACE
  rm $SMB_STORAGE_CLASS_FILE
fi

# Install MetalLB https://metallb.universe.tf/installation/

if [[ $k8sCNI != "none" ]]; then
  echo -e "\033[32mInstall and Configure MetalLB\033[0m"

  kubectl create namespace metallb-system || true
  helm repo add metallb https://metallb.github.io/metallb
  helm repo update
  helm upgrade -i metallb metallb/metallb -n metallb-system $WAIT

  # https://metallb.universe.tf/configuration/_advanced_l2_configuration/
  export METALLB_IPPOOL_L2AD="metallb-ippool-l2ad.yaml" 
  cat <<EOF > $METALLB_IPPOOL_L2AD
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: local-lan-pool
  namespace: metallb-system
spec:
  addresses:
  - $k8sLoadBalancerIPRange
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
EOF

  kubectl apply -f $METALLB_IPPOOL_L2AD -n metallb-system
  rm $METALLB_IPPOOL_L2AD
else
  echo -e "\033[33mSkipping Metal LB step. You will need to run this manually once you've added another node in order to access your pods from your local network.\033[0m"
fi

# Install Metrics Server

echo -e "\033[32mInstall Metrics Server\033[0m"

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system --set args={--kubelet-insecure-tls} $WAIT

# Print success message and tips

export JOIN_COMMAND_OUTPUT=$(kubeadm token create --print-join-command)
read -ra JOIN_WORDS <<< "$JOIN_COMMAND_OUTPUT"

export JOIN_IP=$(echo ${JOIN_WORDS[2]} | cut -d: -f1)
export JOIN_PORT=$(echo ${JOIN_WORDS[2]} | cut -d: -f2)
export JOIN_TOKEN="${JOIN_WORDS[4]}"
export JOIN_CERT_HASH="${JOIN_WORDS[6]}"

echo -e "\033[32m\nInstallation Complete!\n\033[0m"
echo -e "\033[36mRun \033[0m\033[35mkubectl get nodes\033[0m\033[36m to test your connection to your master node.\033[0m"
echo -e "\033[36mRun \033[0m\033[35mcat ~/.kube/config\033[0m\033[36m to get the kube config. You can use this on your workstation with kubectl or Lens to manager your new cluster.\033[0m"
echo -e "\033[36mRun \033[0m\033[35mkubeadm token create --print-join-command\033[0m\033[36m to print the node join command for your cluster. \033[0m"
echo -e "\033[36m\nThe Kubernetes node join command is:\n\033[0m\033[35m$JOIN_COMMAND_OUTPUT\033[0m"
echo -e "\033[36m\nThe Autok8s node join command which uses the setup_worker_node.sh script is:\033[0m\033[35m"
echo -e "curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_worker_node.sh | sudo bash -s -- \\
    --k8s-master-ip $JOIN_IP \\
    --k8s-master-port $JOIN_PORT \\
    --token $JOIN_TOKEN \\
    --discovery-token-ca-cert-hash $JOIN_CERT_HASH\n"
