#!/bin/bash
set -euo pipefail

export PATH="/usr/sbin:/sbin:$PATH"

echo -e '\e[35m      _         _       \e[36m _    ___       \e[0m'
echo -e '\e[35m     / \  _   _| |_ ___ \e[36m| | _( _ ) ___  \e[0m'
echo -e '\e[35m    / ▲ \| | | | __/   \\\e[36m| |/ /   \/ __| \e[0m'
echo -e '\e[35m   / ___ \ |_| | ||  ●  \e[36m|   <  ♥  \__ \ \e[0m'
echo -e '\e[35m  /_/   \_\__,_|\__\___/\e[36m|_|\_\___/|___/ \e[0m'
echo -e '\e[35m                Version:\e[36m 1.7.0\e[0m\n'
echo -e '\e[35m  Kubernetes Cleanup Script:\e[36m Worker Node Edition\e[0m\n'

if [ "$(id -u)" -ne 0 ]; then
  echo -e "\033[31mYou must run this script as root\033[0m"
  exit 1
fi

sudo -v
while true; do
  sudo -nv; sleep 1m
  kill -0 $$ 2>/dev/null || exit
done &

export APT_LOCK="-o DPkg::Lock::Timeout=600"

# Reset Kubernetes
# --------------------------------------------------------------------------------------------------------------------------------------------------------

echo -e "\033[32mResetting Kubernetes\033[0m"

if command -v kubeadm &>/dev/null; then
  kubeadm reset -f || true
else
  echo "kubeadm not found, skipping reset"
fi

# Remove CNI interfaces and configs
# --------------------------------------------------------------------------------------------------------------------------------------------------------

echo -e "\033[32mRemoving CNI\033[0m"

for iface in flannel.1 cni0 cilium_host cilium_net cilium_vxlan lxc_health; do
  ip link delete $iface 2>/dev/null || true
done

rm -rf /etc/cni/net.d
rm -rf /opt/cni/bin
rm -rf /var/lib/cni

# Remove Kubernetes packages
# --------------------------------------------------------------------------------------------------------------------------------------------------------

echo -e "\033[32mRemoving Kubernetes packages\033[0m"

apt-mark unhold kubeadm kubelet kubectl 2>/dev/null || true
apt-get purge -qqy $APT_LOCK kubeadm kubelet kubectl 2>/dev/null || true

# Remove Kubernetes apt repo and keyring

export KEYRINGS_DIR="/etc/apt/keyrings"

rm -f /etc/apt/sources.list.d/kubernetes.list
rm -f $KEYRINGS_DIR/kubernetes-apt-keyring.gpg

# Remove containerd
# --------------------------------------------------------------------------------------------------------------------------------------------------------

echo -e "\033[32mRemoving containerd\033[0m"

systemctl stop containerd 2>/dev/null || true
systemctl disable containerd 2>/dev/null || true
apt-get purge -qqy $APT_LOCK containerd 2>/dev/null || true
rm -rf /etc/containerd
rm -rf /var/lib/containerd

# Remove leftover kubernetes data dirs
# --------------------------------------------------------------------------------------------------------------------------------------------------------

rm -rf /var/lib/kubelet
rm -rf /etc/kubernetes

# Remove kernel module and sysctl configs
# --------------------------------------------------------------------------------------------------------------------------------------------------------

echo -e "\033[32mRemoving kernel configs\033[0m"

rm -f /etc/modules-load.d/k8s.conf
rm -f /etc/sysctl.d/k8s.conf
sysctl --system 2>/dev/null || true

# Re-enable swap
# --------------------------------------------------------------------------------------------------------------------------------------------------------

LATEST_FSTAB_BACKUP=$(ls -t /etc/fstab.backup.* 2>/dev/null | head -1 || true)

if [ -n "$LATEST_FSTAB_BACKUP" ]; then
  echo -e "\033[32mRestoring /etc/fstab from $LATEST_FSTAB_BACKUP\033[0m"
  cp "$LATEST_FSTAB_BACKUP" /etc/fstab
  swapon -a 2>/dev/null || true
else
  sed -i '/^#.*swap/ s/^#//' /etc/fstab 2>/dev/null || true
  swapon -a 2>/dev/null || true
fi

# Revert needsrestart config
# --------------------------------------------------------------------------------------------------------------------------------------------------------

export NEEDSRESART_CONF="/etc/needrestart/needrestart.conf"

if [ -f $NEEDSRESART_CONF ]; then
  sed -i "/^\\\$nrconf{restart} = 'a';/s/.*/\#\$nrconf{restart} = 'i';/" $NEEDSRESART_CONF 2>/dev/null || true
fi

# Final apt cleanup
# --------------------------------------------------------------------------------------------------------------------------------------------------------

echo -e "\033[32mCleaning up packages\033[0m"

apt-get update -qq $APT_LOCK
apt-get autoremove -qqy $APT_LOCK
apt-get autoclean -qq

echo -e "\033[32m\nCleanup Complete!\n\033[0m"
