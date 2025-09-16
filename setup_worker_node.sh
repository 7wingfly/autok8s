#!/bin/bash
set -euo pipefail

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.6.1\e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m Worker Node Edition\e[0m\n'

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
export ipAddress=""
export netmask=""
export defaultGateway=""
export dnsServers=("8.8.8.8" "4.4.4.4")                     # Don't specify more than 3. K8s will only use the first three and throw errors.
export dnsSearch=("domain.local")                           # Your local DNS search domain if you have one.

# ------------------------------
# Kubernetes
# ------------------------------
#
export k8sVersion="latest"
export k8sMasterIP=""
export k8sMasterPort="6443"
export k8sToken=""                                          # This and the cert hash can be found by running 'kubeadm token create --print-join-command' on the master node
export k8sTokenDiscoveryCaCertHash=""                       
export k8sKubeadmOptions=""                                 # Additional options you can pass into the kubeadm join command.

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
        --k8s-master-ip) k8sMasterIP="$2"; shift; shift;;
        --k8s-master-port) k8sMasterPort="$2"; shift; shift;;
        --k8s-kubeadm-options) k8sKubeadmOptions="$2"; shift; shift;;
        --token) k8sToken="$2"; shift; shift;;
        --discovery-token-ca-cert-hash) k8sTokenDiscoveryCaCertHash="$2"; shift; shift;;
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

# Perform Validation
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export HARDWARE_CHECK_PASS=true
export PARAM_CHECK_WARN=false

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

if [[ ! "$configureTCPIPSetting" =~ ^(true|false)$ ]]; then
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

if [[ ! $k8sVersion =~ ^(latest|[0-9]{1,2}(\.[0-9]{1,2}){1,2})$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--k8s-version\e[0m value \e[35m$k8sVersion\e[0m is not in the correct format."
    PARAM_CHECK_PASS=false
fi

if [[ -z "$k8sMasterIP" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-master-ip\e[0m is required."
  PARAM_CHECK_PASS=false
elif [[ ! $k8sMasterIP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-master-ip\e[0m value \e[35m$k8sMasterIP\e[0m is not a valid IP address."
  PARAM_CHECK_PASS=false
fi

if [[ -z "$k8sMasterIP" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-master-ip\e[0m is required."
  PARAM_CHECK_PASS=false
fi

if [[ -z "$k8sMasterPort" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-master-port\e[0m is required."
  PARAM_CHECK_PASS=false
fi

if [[ -z "$k8sToken" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--token\e[0m is required."
  PARAM_CHECK_PASS=false
fi

if [[ -z "$k8sTokenDiscoveryCaCertHash" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--discovery-token-ca-cert-hash\e[0m is required."
  PARAM_CHECK_PASS=false
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

if [ $configureTCPIPSetting == true ]; then

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

export APT_LOCK="-o DPkg::Lock::Timeout=600"

echo -e "\033[32mInstalling prerequisites\033[0m"

apt-get update -qq $APT_LOCK
apt-get install -qqy $APT_LOCK apt-transport-https ca-certificates curl software-properties-common gzip gnupg lsb-release

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

apt-get update -qq $APT_LOCK
apt-get install -qqy $APT_LOCK docker-ce docker-ce-cli

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

normalize_k8s_version() {
  case "$1" in
    latest) echo latest ;;
    v*|V*)  echo "${1#v}" | sed 's/^V//' ;;
    *)      echo "$1" ;;
  esac
}

pick_pkg_ver() {
  apt-cache madison "$1" | awk -v re="$2" '$3 ~ re { print $3; exit }'
}

if [ $k8sVersion == "latest" ]; then
  k8sVersion=$(curl -s https://api.github.com/repos/kubernetes/kubernetes/releases/latest | grep tag_name | cut -d '"' -f4 | sed 's/^v//')
  echo "Detected latest Kubernetes version: $k8sVersion"
fi

k8sVersion="$(normalize_k8s_version "$k8sVersion")"
IFS=. read -r K8S_MAJ K8S_MIN K8S_PATCH <<<"$k8sVersion"
export K8S_REPO_VERSION="v${K8S_MAJ}.${K8S_MIN}"

echo "Kubernetes version: $k8sVersion"
echo "Using APT repo: $K8S_REPO_VERSION"

if [ -n "$K8S_PATCH" ]; then  
  VER_REGEX="^${K8S_MAJ}\\\\.${K8S_MIN}\\\\.${K8S_PATCH}-"
  KUBEADM_VERSION="v${K8S_MAJ}.${K8S_MIN}.${K8S_PATCH}"
else  
  VER_REGEX="^${K8S_MAJ}\\\\.${K8S_MIN}\\\\.[0-9]+-"  
  KUBEADM_VERSION=""
fi

# Add Kubernetes Respository

if [ -f /etc/apt/sources.list.d/kubernetes.list ]; then
  rm $KEYRINGS_DIR/kubernetes-apt-keyring.gpg
  rm /etc/apt/sources.list.d/kubernetes.list
fi

echo -e "\033[32mAdding Kubernetes community repository\033[0m"
curl -fsSL https://pkgs.k8s.io/core:/stable:/$K8S_REPO_VERSION/deb/Release.key | gpg --dearmor -o $KEYRINGS_DIR/kubernetes-apt-keyring.gpg    
echo "deb [signed-by=$KEYRINGS_DIR/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$K8S_REPO_VERSION/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -qq $APT_LOCK

kubeadm_ver="$(pick_pkg_ver kubeadm $VER_REGEX)"
kubelet_ver="$(pick_pkg_ver kubelet $VER_REGEX)"
kubectl_ver="$(pick_pkg_ver kubectl $VER_REGEX)"

echo "Resolved kubeadm version: $kubeadm_ver"
echo "Resolved kubelet version: $kubelet_ver"
echo "Resolved kubectl version: $kubectl_ver"

if [ -z "$kubeadm_ver" ] || [ -z "$kubelet_ver" ] || [ -z "$kubectl_ver" ]; then
  echo -e "\e[31mError:\e[0m Could not find requested version in $K8S_REPO_VERSION.\n\nAvailable kubeadm versions in this minor:"  
  apt-cache madison kubeadm | sed 's/^/  /'
  exit 1
fi

if [ -z "$KUBEADM_VERSION" ]; then  
  KUBEADM_VERSION="v$(echo "$kubeadm_ver" | cut -d- -f1)"
fi

echo "Using kubeadm version: $KUBEADM_VERSION"

apt-get install -qqy $APT_LOCK kubeadm="$kubeadm_ver" kubelet="$kubelet_ver" kubectl="$kubectl_ver"

apt-mark hold kubeadm kubelet kubectl

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

# Join Cluster

echo -e "\033[32mJoining Kubernetes Cluster\033[0m"

kubeadm join $k8sMasterIP:$k8sMasterPort --token $k8sToken --discovery-token-ca-cert-hash $k8sTokenDiscoveryCaCertHash $k8sKubeadmOptions

# Print success message

echo -e "\033[32m\nInstallation Complete!\n\033[0m"
