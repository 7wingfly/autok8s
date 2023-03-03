#!/bin/bash

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
export nfsSharePath="/shares/nfs"   # Local server only
export nfsDefaultStorageClass=false

export smbInstallServer=true
export smbServer=$HOSTNAME
export smbSharePath="/shares/smb"   # Local server only
export smbShareName="persistentvolumes"
export smbUsername=$SUDO_USER
export smbPassword="password"
export smbDefaultStorageClass=true  # Only one storage class should be set as default.

# REMOTE SMB SERVER CONFIG EXAMPLE:

# export smbInstallServer=false
# export smbServer="FileServer01"
# export smbShareName="pvs"
# export smbUsername="user@domain.local"
# export smbPassword="SecurePassword"
# export smbDefaultStorageClass=false 

# Install NFS Server and/or CSI and Storage Classes https://github.com/kubernetes-csi/csi-driver-nfs

export INSTALL_NFS_DRIVER=false

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

# NFS CSI Driver https://github.com/kubernetes-csi/csi-driver-nfs/tree/master/charts

if [ $INSTALL_NFS_DRIVER == true ]; then
  echo -e "\033[32mInstall NFS CSI driver Helm chart\033[0m"
  export NFS_SERVER_NAME_SAFE=$(echo "$nfsServer" | tr '.' '-')
  export NFS_NAME_SPACE="kube-system"    
  export NFS_STORAGE_CLASS_FILE="nfsStorageClass.yaml"
  helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts 
  helm install csi-driver-nfs csi-driver-nfs/csi-driver-nfs --namespace $NFS_NAME_SPACE
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

export INSTALL_SMB_DRIVER=false

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
  export SMB_SERVER_NAME_SAFE=$(echo "$smbServer" | tr '.' '-')
  export SMB_NAME_SPACE="kube-system"
  export SMB_SECRET_NAME="smb-credentials-$SMB_SERVER_NAME_SAFE"  
  export SMB_STORAGE_CLASS_FILE="smbStorageClass.yaml"
  helm repo add csi-driver-smb https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/master/charts
  helm install csi-driver-smb csi-driver-smb/csi-driver-smb --namespace $SMB_NAME_SPACE --set controller.runOnControlPlane=true
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

echo -e "\033[32mComplete\033[0m"