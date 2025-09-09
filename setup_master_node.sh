#!/bin/bash
set -euo pipefail

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.5.0\e[0m\n'
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
export k8sClusterName="kubernetes"                          # Name of your Kubernetes cluster. Cannot be used with 'k8sKubeadmConfig'.
export k8sVersion="latest"                                  # You can specify a specific version such as "1.34.0-00".
export k8sPodNetworkCIDR="10.244.0.0/16"                    # Pod network CIDR. Cannot be used with 'k8sKubeadmConfig'.
export k8sServiceCIDR="10.96.0.0/12"                        # Service network CIDR. Cannot be used with 'k8sKubeadmConfig'.
export k8sLoadBalancerIPRange=""                            # Either a range such as "192.168.0.100-192.168.0.150" or a CIDR.
export k8sCNI="flannel"                                     # Choose a Kubernetes network plugin.
export k8sAllowMasterNodeSchedule=true                      # Disabling this is best practice if you're only going to have a single node.
export k8sKubeadmOptions=""                                 # Additional options you can pass into the kubeadm init command. Do not include --config, --apiserver-advertise-address, --pod-network-cidr or --service-cidr.
export k8sKubeadmConfig=""                                  # Path to kubeadm config file. Cannot be used with 'k8sClusterName', 'k8sPodNetworkCIDR' or 'k8sServiceCIDR'.

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
export smbDefaultStorageClass=true                          # Only one storage class should be set as default.

# ------------------------------
# Flux
# ------------------------------
#
export fluxInstall=false
export fluxGitHost="github.com"
export fluxGitBranch="main"
export fluxGitOrg=""
export fluxGitRepo=""
export fluxGitPath=""
export fluxGitHttpsUseTokenAuth=false
export fluxGitHttpsUseBearerToken=false
export fluxGitAuthMethod=""
export fluxGitSshPrivateKeyFile=""
export fluxGitHttpsUsername=""
export fluxGitHttpsPassword=""
export fluxGitHttpsCAFile=""
export fluxGitSshPrivateKeyPassword=""
export fluxOptions=""

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
        --k8s-cluster-name) k8sClusterName="$2"; shift; shift;;
        --k8s-version) k8sVersion="$2"; shift; shift;;
        --k8s-pod-network-cidr) k8sPodNetworkCIDR="$2"; shift; shift;;
        --k8s-service-cidr) k8sServiceCIDR="$2"; shift; shift;;
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
        --flux-install) fluxInstall="$2"; shift; shift;;
        --flux-git-host) fluxGitHost="$2"; shift; shift;;
        --flux-git-org) fluxGitOrg="$2"; shift; shift;;
        --flux-git-repo) fluxGitRepo="$2"; shift; shift;;
        --flux-git-branch) fluxGitBranch="$2"; shift; shift;;
        --flux-git-path) fluxGitPath="$2"; shift; shift;;
        --flux-git-auth-method) fluxGitAuthMethod="$2"; shift; shift;;
        --flux-git-ssh-private-key-file) fluxGitSshPrivateKeyFile="$2"; shift; shift;;
        --flux-git-ssh-private-key-password) fluxGitSshPrivateKeyPassword="$2"; shift; shift;;
        --flux-git-https-username) fluxGitHttpsUsername="$2"; shift; shift;;
        --flux-git-https-password) fluxGitHttpsPassword="$2"; shift; shift;;
        --flux-git-https-use-token-auth) fluxGitHttpsUseTokenAuth="$2"; shift; shift;;
        --flux-git-https-use-bearer-token) fluxGitHttpsUseBearerToken="$2"; shift; shift;;
        --flux-git-https-ca-file) fluxGitHttpsCAFile="$2"; shift; shift;;
        --flux-options) fluxOptions="$2"; shift; shift;;  
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
    echo -e "\e[31mError:\e[0m \e[35m--k8s-cni\e[0m value \e[35m$k8sCNI\e[0m is not valid. Options are: \e[35mflannel\e[0m (default), \e[35mcilium\e[0m or \e[35mnone\e[0m."
    PARAM_CHECK_PASS=false
fi

if [[ ! $k8sPodNetworkCIDR =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--k8s-pod-network-cidr\e[0m value \e[35m$k8sPodNetworkCIDR\e[0m is not a valid CIDR."
    PARAM_CHECK_PASS=false
fi

if [[ ! $k8sServiceCIDR =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--k8s-service-cidr\e[0m value \e[35m$k8sServiceCIDR\e[0m is not a valid CIDR."
    PARAM_CHECK_PASS=false
fi

if [[ ! "$k8sClusterName" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-cluster-name\e[0m value \e[35m$k8sClusterName\e[0m is invalid."
  PARAM_CHECK_PASS=false
elif [[ "$k8sCNI" == "cilium" && "$k8sClusterName" =~ [A-Z] ]]; then
  echo -e "\e[31mError:\e[0m The cluster name must be lower case when using Cilium CNI."
  PARAM_CHECK_PASS=false
elif [[ "$k8sClusterName" =~ [A-Z] ]]; then
  echo -e "\e[33mWarning:\e[0m Your cluster name contains uppercase characters. You may experience issues if you later change your CNI to Cilium."
  PARAM_CHECK_WARN=true
fi

if [ $k8sCNI == "none" ]; then
  echo -e "\033[33mWarning:\033[0m You have chosen not to install a CNI. Your master node will not be in a 'ready' state until you install one."
  PARAM_CHECK_WARN=true
fi

if [[ "$k8sKubeadmOptions" =~ "--config" ]]; then
  echo -e "\e[31mError:\e[0m You cannot use the \e[35m--config\e[0m argument inside of \e[35m--k8s-kubeadm-options\e[0m. Instead use \e[35m--k8s-kubeadm-config <config file>\e[0m.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ "$k8sKubeadmOptions" =~ "--apiserver-advertise-addres" ]]; then
  echo -e "\e[31mError:\e[0m You cannot use the \e[35m--apiserver-advertise-address\e[0m argument inside of \e[35m--k8s-kubeadm-options\e[0m as it's already set from current IP or \e[35m--ip-address\e[0m.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ "$k8sKubeadmOptions" =~ "--pod-network-cidr" ]]; then
  echo -e "\e[31mError:\e[0m You cannot use the \e[35m--pod-network-cidr\e[0m argument inside of \e[35m--k8s-kubeadm-options\e[0m as it's already included. Pass in with \e[35m--k8s-pod-network-cidr\e[0m instead.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ "$k8sKubeadmOptions" =~ "--service-cidr" ]]; then
  echo -e "\e[31mError:\e[0m You cannot use the \e[35m--service-cidr\e[0m argument inside of \e[35m--k8s-kubeadm-options\e[0m as it's already included. Pass in with \e[35m--k8s-service-cidr\e[0m instead.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && ! -f "$k8sKubeadmConfig" ]]; then
  echo -e "\e[31mError:\e[0m The file \e[35m$k8sKubeadmConfig\e[0m specfied for \e[35m--k8s-kubeadm-config\e[0m does not exist.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && "$k8sPodNetworkCIDR" != "10.244.0.0/16" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-kubeadm-config\e[0m and \e[35m--k8s-pod-network-cidr\e[0m cannot be used at the same time. (Define this in your config file instead).\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && "$k8sServiceCIDR" != "10.96.0.0/12" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-kubeadm-config\e[0m and \e[35m--k8s-service-cidr\e[0m cannot be used at the same time. (Define this in your config file instead).\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && "$k8sClusterName" != "kubernetes" ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--k8s-kubeadm-config\e[0m and \e[35m--k8s-cluster-name\e[0m cannot be used at the same time. (Define this in your config file instead).\e[0m"
  PARAM_CHECK_PASS=false
fi

if [[ ! -z "$k8sKubeadmConfig" && ! -z "$k8sKubeadmOptions" ]]; then
  echo -e "\e[33mWarning:\e[0m Using \e[35m--k8s-kubeadm-config\e[0m with \e[35m--k8s-kubeadm-options\e[0m may cause kubeadm init to fail depending on the options used.\e[0m"
  PARAM_CHECK_WARN=true
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

if [[ ! "$fluxInstall" =~ ^(true|false)$ ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--install-flux\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
  PARAM_CHECK_PASS=false
elif [[ "$fluxInstall" = true ]]; then
  if [[ -z "$fluxGitOrg" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--flux-git-org\e[0m is required when \e[35m--install-flux\e[0m is set to \e[35mtrue\e[0m. If you are not part of an organisation, use your username."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$fluxGitRepo" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--flux-git-repo\e[0m is required when \e[35m--install-flux\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$fluxGitRepo" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--flux-git-repo\e[0m is required when \e[35m--install-flux\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$fluxGitPath" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--flux-git-path\e[0m is required when \e[35m--install-flux\e[0m is set to \e[35mtrue\e[0m. This would typically be something like \e[35mclusters/my-cluster\e[0m."
    PARAM_CHECK_PASS=false
  fi
  if [[ -z "$fluxGitAuthMethod" ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--flux-git-auth-method\e[0m is required when \e[35m--install-flux\e[0m is set to \e[35mtrue\e[0m."
    PARAM_CHECK_PASS=false  
  elif [[ ! "$fluxGitAuthMethod" =~ ^(ssh|https)$ ]]; then
    echo -e "\e[31mError:\e[0m \e[35m--flux-git-auth-method\e[0m must be set to either \e[35mssh\e[0m or \e[35mhttps\e[0m."
    PARAM_CHECK_PASS=false
  else
    if [[ "$fluxGitAuthMethod" == "ssh" ]]; then      
      if [[ -z "$fluxGitSshPrivateKeyFile" ]]; then
        echo -e "\e[31mError:\e[0m \e[35m--flux-git-ssh-private-key-file\e[0m is required if \e[35m--flux-git-auth-method\e[0m is set to \e[35mssh\e[0m."
        PARAM_CHECK_PASS=false
      elif [[ ! -f "$fluxGitSshPrivateKeyFile" ]]; then
        echo -e "\e[31mError:\e[0m Flux Git SSH private key file not found: \e[35m$fluxGitSshPrivateKeyFile\e[0m. Please check \e[35m--flux-git-ssh-private-key-file\e[0m."
        PARAM_CHECK_PASS=false
      else
        if [[ "$(stat -c "%a" "$fluxGitSshPrivateKeyFile")" != "600" ]]; then
          echo -e "\e[33mWarning:\e[0m Flux Git SSH private key file permissions are not 600. Fixing permissions..."
          chmod 600 "$fluxGitSshPrivateKeyFile"
        fi
        if ! KEY_TEST_RESULT=$(ssh-keygen -y -f "$fluxGitSshPrivateKeyFile" -P "$fluxGitSshPrivateKeyPassword" 2>&1); then          
          if [[ $KEY_TEST_RESULT =~ "error in libcrypto" ]]; then
            echo -e "\e[31mError:\e[0m Flux Git SSH private key file could read. Check formatting and line endings (LF, not CRLF)\e[0m."
            PARAM_CHECK_PASS=false
          elif [[ $KEY_TEST_RESULT =~ "incorrect passphrase" ]] && [[ -z "$fluxGitSshPrivateKeyPassword" ]]; then
            echo -e "\e[31mError:\e[0m Flux Git SSH private key file requires a password. Please include \e[35m--flux-git-ssh-private-key-password\e[0m."
            PARAM_CHECK_PASS=false
          elif [[ $KEY_TEST_RESULT =~ "incorrect passphrase" ]]; then
            echo -e "\e[31mError:\e[0m Flux Git SSH private key file password is incorrect. Please check \e[35m--flux-git-ssh-private-key-password\e[0m."
            PARAM_CHECK_PASS=false
          else 
            echo -e "\e[31mError:\e[0m Flux Git SSH private key file could not be loaded. Error: $KEY_TEST_RESULT\e[0m."
            PARAM_CHECK_PASS=false
          fi        
        elif KEY_TEST_RESULT_NO_PW=$(ssh-keygen -y -f "$fluxGitSshPrivateKeyFile" -P "" 2>&1) && [[ ! -z "$fluxGitSshPrivateKeyPassword" ]]; then
            echo -e "\e[33mWarning:\e[0m Flux Git SSH private key file does not require a password but you have provded one anyway. This will be ignored."
            fluxGitSshPrivateKeyPassword=""
        fi        
      fi
    elif [[ "$fluxGitAuthMethod" == "https" ]]; then
      if [[ -z "$fluxGitHttpsPassword" ]]; then
        echo -e "\e[31mError:\e[0m \e[35m--flux-git-https-password\e[0m is required if \e[35m--flux-git-auth-method\e[0m is set to \e[35mhttp\e[0m."
        PARAM_CHECK_PASS=false
      fi      
      if [[ ! "$fluxGitHttpsUseTokenAuth" =~ ^(true|false)$ ]]; then
        echo -e "\e[31mError:\e[0m \e[35m--flux-git-https-use-token-auth\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
        PARAM_CHECK_PASS=false
      elif [[ ! "$fluxGitHttpsUseBearerToken" =~ ^(true|false)$ ]]; then
        echo -e "\e[31mError:\e[0m \e[35m--flux-git-https-use-bearer-token\e[0m must be set to either \e[35mtrue\e[0m or \e[35mfalse\e[0m."
        PARAM_CHECK_PASS=false
      elif [[ "$fluxGitHttpsUseTokenAuth" == true && "$fluxGitHttpsUseBearerToken" == true ]]; then
        echo -e "\e[31mError:\e[0m Cannot set both \e[35m--flux-git-https-use-token-auth\e[0m and \e[35m--flux-git-https-use-bearer-token\e[0m to true\e[0m.."
        PARAM_CHECK_PASS=false
      elif [[ "$fluxGitHttpsUseBearerToken" = false ]] && [[ -z "$fluxGitHttpsUsername" ]]; then
        echo -e "\e[31mError:\e[0m \e[35m--flux-git-https-username\e[0m is required when \e[35m--flux-git-https-use-bearer-token\e[0m is \e[35mfalse\e[0m."
        PARAM_CHECK_PASS=false
      fi
      if [[ -n "$fluxGitHttpsCAFile" ]] && [[ ! -f "$fluxGitHttpsCAFile" ]]; then
        echo -e "\e[31mError:\e[0m Flux Git CA file not found: \e[35m$fluxGitHttpsCAFile\e[0m. Please check \e[35m--flux-git-https-ca-file\e[0m."
        PARAM_CHECK_PASS=false
      fi
      if [[ "$fluxGitHost" == "github.com" && "$fluxGitHttpsUseTokenAuth" == false && "$fluxGitHttpsUseBearerToken" == false ]]; then
        echo -e "\e[31mError:\e[0m When connecting to GitHub via HTTPS you must set either \e[35m--flux-git-https-use-token-auth true\e[0m or \e[35m--flux-git-https-use-bearer-token true\e[0m."
        PARAM_CHECK_PASS=false
      fi
    fi
  fi
fi

if [[ "$nfsDefaultStorageClass" = true && "$smbDefaultStorageClass" = true ]]; then
  echo -e "\e[31mError:\e[0m \e[35m--smb-default-storage-class\e[0m and \e[35m--nfs-default-storage-class\e[0m cannot both be set to \e[35mtrue\e[0m at the same time.\e[0m"
  PARAM_CHECK_PASS=false
fi

if [ $PARAM_CHECK_PASS == false ]; then
  exit 1
fi

if [ $PARAM_CHECK_WARN == true ]; then
  sleep 10
fi

if [[ "$nfsDefaultStorageClass" = false && "$smbDefaultStorageClass" = false ]]; then
  echo -e "\e[32mInfo:\e[0m The default storage class will be set to \e[35msmb\e[0m"
  smbDefaultStorageClass=true
fi

echo -e "\e[32mInfo:\e[0m The cluster name will be \e[35m$k8sClusterName\e[0m"
echo -e "\e[32mInfo:\e[0m The pod network will be \e[35m$k8sPodNetworkCIDR\e[0m"
echo -e "\e[32mInfo:\e[0m The service network will be \e[35m$k8sServiceCIDR\e[0m"

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

export APT_LOCK="-o DPkg::Lock::Timeout=600"

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

apt-get update -qq $APT_LOCK
apt-get install -qqy $APT_LOCK kubelet kubeadm kubectl

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

if [[ -z "$k8sKubeadmConfig" && "$k8sClusterName" == "kubernetes" ]]; then  
  export KUBEADM_ARGS="--apiserver-advertise-address=$ipAddress --pod-network-cidr=$k8sPodNetworkCIDR --service-cidr=$k8sServiceCIDR"
else 
  if [[ -z "$k8sKubeadmConfig" ]]; then
    export k8sKubeadmConfig="/tmp/kubeadm-config.yaml"
    cat <<EOF > $k8sKubeadmConfig
apiVersion: kubeadm.k8s.io/v1beta3
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$ipAddress"
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
clusterName: "$k8sClusterName"
networking:
  podSubnet: "$k8sPodNetworkCIDR"
  serviceSubnet: "$k8sServiceCIDR"

EOF
  fi
  echo -e "\033[32mValidating kubeadm config file\033[0m"
  kubeadm config validate --config $k8sKubeadmConfig
  export KUBEADM_ARGS="--config $k8sKubeadmConfig"
fi

echo -e "\033[32mInitilizing Kubernetes\033[0m"

kubeadm init $KUBEADM_ARGS $k8sKubeadmOptions

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

if [ $k8sAllowMasterNodeSchedule == true ]; then
  echo -e "\033[32mRemoving NoSchedule taints\033[0m"

  kubectl taint node $hostname_lower node-role.kubernetes.io/control-plane:NoSchedule- || true
  kubectl taint node $hostname_lower node-role.kubernetes.io/master:NoSchedule- || true # for older versions
fi

# Install a CNI

if [ $k8sCNI == "flannel" ]; then
  # Flannel https://github.com/flannel-io/flannel/#readme

  echo -e "\033[32mInstalling CNI: Flannel\033[0m"

  sysctl net.bridge.bridge-nf-call-iptables=1
  sysctl -p
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml --wait --timeout=2m

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
  
  cilium status --wait
fi

# Install Helm

echo -e "\033[32mInstalling Helm\033[0m"

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install NFS Server and/or CSI and Storage Classes https://github.com/kubernetes-csi/csi-driver-nfs

export INSTALL_NFS_DRIVER=false # Do not edit. Will be set to true if required

if [ $nfsInstallServer == true ]; then
  echo -e "\033[32mInstall NFS File Server\033[0m"

  apt-get install -qqy $APT_LOCK nfs-kernel-server
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

  apt-get install -qqy $APT_LOCK samba
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
  helm upgrade --install metallb metallb/metallb -n metallb-system --wait \
    --set controller.tolerations[0].key=node-role.kubernetes.io/control-plane \
    --set controller.tolerations[0].operator=Exists \
    --set controller.tolerations[0].effect=NoSchedule \
    --set controller.tolerations[1].key=node-role.kubernetes.io/master \
    --set controller.tolerations[1].operator=Exists \
    --set controller.tolerations[1].effect=NoSchedule

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
  echo -e "\033[33mSkipping Metal LB step. You will need to run this manually once you've installed a CNI in order to access your pods from your local network.\033[0m"
fi

# Install Metrics Server

echo -e "\033[32mInstall Metrics Server\033[0m"

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
  --set args={--kubelet-insecure-tls} \
  --set tolerations[0].key=node-role.kubernetes.io/control-plane \
  --set tolerations[0].operator=Exists \
  --set tolerations[0].effect=NoSchedule \
  --set tolerations[1].key=node-role.kubernetes.io/master \
  --set tolerations[1].operator=Exists \
  --set tolerations[1].effect=NoSchedule    

# Install and bootstrap Flux CD

if [[ "$fluxInstall" = true ]]; then
  curl -s https://fluxcd.io/install.sh | sudo bash
  command -v flux >/dev/null && . <(flux completion bash)

  export KUBECONFIG=/etc/kubernetes/admin.conf

  if [[ "$fluxGitAuthMethod" == "ssh" ]]; then
    FLUX_BOOTSTRAP_ARGS="--url=ssh://git@$fluxGitHost/$fluxGitOrg/$fluxGitRepo --private-key-file=$fluxGitSshPrivateKeyFile"
    if [[ -n "$fluxGitSshPrivateKeyPassword" ]]; then
      FLUX_BOOTSTRAP_ARGS="$FLUX_BOOTSTRAP_ARGS --password=$fluxGitSshPrivateKeyPassword"
    fi
  elif [[ "$fluxGitAuthMethod" == "https" ]]; then
    FLUX_BOOTSTRAP_ARGS="--url=https://$fluxGitHost/$fluxGitOrg/$fluxGitRepo --password=$fluxGitHttpsPassword"
    if [[ "$fluxGitHttpsUseBearerToken" = false && -n "$fluxGitHttpsUsername" ]]; then
      FLUX_BOOTSTRAP_ARGS="$FLUX_BOOTSTRAP_ARGS --username=$fluxGitHttpsUsername"
    fi
    if [[ "$fluxGitHttpsUseTokenAuth" = true ]]; then
      FLUX_BOOTSTRAP_ARGS="$FLUX_BOOTSTRAP_ARGS --token-auth=true"
    elif [[ "$fluxGitHttpsUseBearerToken" = true ]]; then
      FLUX_BOOTSTRAP_ARGS="$FLUX_BOOTSTRAP_ARGS --with-bearer-token"
    fi
    if [[ -n "$fluxGitHttpsCAFile" ]]; then
      FLUX_BOOTSTRAP_ARGS="$FLUX_BOOTSTRAP_ARGS --ca-file=$fluxGitHttpsCAFile"
    fi
  fi

  flux bootstrap git $FLUX_BOOTSTRAP_ARGS --branch=$fluxGitBranch --path=$fluxGitPath --silent $fluxOptions
fi

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
