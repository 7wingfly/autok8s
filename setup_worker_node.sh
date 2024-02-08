#!/bin/bash

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
export k8sToken=""                                          # This and the cert hash can be found by running 'kubeadm token create --print-join-command'
export k8sTokenDiscoveryCaCertHash=""                       # on the master node

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
        --token) k8sToken="$2"; shift; shift;;
        --discovery-token-ca-cert-hash) k8sTokenDiscoveryCaCertHash="$2"; shift; shift;;
        *) echo -e "\e[31mError:\e[0m Parameter \e[35m$key\e[0m is not recognised."; exit 1;;
    esac
done

echo -e '\e[35m      _         _        \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___  \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / _ \| | | | __/ _ \ \e[36m| |/ / _ \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | || (_) |\e[36m|   < (_) \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/ \e[36m|_|\_\___/|___/ \e[0m\n'
echo -e '\e[35m  Kubernetes Installation Script:\e[36m Worker Node Edition\e[0m\n'

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
  fi
  for ip in "${dnsServers[@]}"; do
    if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo -e "\e[31mError:\e[0m DNS server \e[35m$ip\e[0m is not a valid IP address."
        PARAM_CHECK_PASS=false
    fi
  done
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

# Install Kubernetes
# --------------------------------------------------------------------------------------------------------------------------------------------------------

# Check sudo & keep sudo running

echo -e "\033[32mChecking root access\033[0m"

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
  echo -e "\033[32mDisabling needsrestart interactive mode\033[0m"  
  sed -i "/#\$nrconf{restart} = 'i';/s/.*/\$nrconf{restart} = 'a';/" $NEEDSRESART_CONF
fi

# Configure IP Settings

if [ $configureTCPIPSetting == true ]; then

  echo -e "\033[32mConfiguring Network Settings\033[0m"

  IFS=. read -r i1 i2 i3 i4 <<< "$ipAddress"
  IFS=. read -r m1 m2 m3 m4 <<< "$netmask"

  cidr=$(echo "obase=2; $(( (m1 << 24) + (m2 << 16) + (m3 << 8) + m4 ))" | bc | tr -d '\n' | sed 's/0*$//' | wc -c)

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

# Install Prerequsites 

echo -e "\033[32mInstalling prerequisites\033[0m"

apt-get update -q
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

# Add Kubernetes Respository

if [ ! -f /etc/apt/sources.list.d/kubernetes.list ]; then
  echo -e "\033[32mAdding Google Kubernetes repository\033[0m"
  curl -fsSLo $KEYRINGS_DIR/kubernetes-archive-keyring.gpg https://dl.k8s.io/apt/doc/apt-key.gpg
  echo "deb [signed-by=$KEYRINGS_DIR/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
fi

apt-get update -q

# Install Docker https://docs.docker.com/engine/install/ubuntu/

echo -e "\033[32mInstalling Docker\033[0m"

apt-get install -qqy docker-ce docker-ce-cli containerd.io
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

# Install Kubernetes https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

echo -e "\033[32mInstalling Kubernetes\033[0m"

if [ $k8sVersion == "latest" ]; then
  apt-get install -qqy kubelet kubeadm kubectl
else
  apt-get install -qqy kubelet=$k8sVersion kubeadm=$k8sVersion kubectl=$k8sVersion
fi

# Join Cluster

echo -e "\033[32mJoining Kubernetes Cluster\033[0m"

kubeadm join $k8sMasterIP:$k8sMasterPort --token $k8sToken --discovery-token-ca-cert-hash $k8sTokenDiscoveryCaCertHash

# Print success message and tips

echo -e "\033[32m\nInstallation Complete!\n\033[0m"
