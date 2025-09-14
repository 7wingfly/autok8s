# Master Node Parameters
The following is a list of all available parameters you can use with the `setup_master_node.sh` script. At the bottom are some examples that can help you get started and some notes on things to watch out for when setting some of the parameter values. 

Parameter values which are wrapped in quotes must include the quotes when applied.
<br>
<br>

|Parameter Name|Description|Default Value|Example Value|Required|
|--- |--- |--- |--- |--- |
|`--configure-tcpip`|Set to `true` to configure TCP/IP settings of this server.|`false`|`true`|No|
|`--interface`|The interface to configure IP settings for.|`eth0`|`ens160`|When `--configure-tcpip` is `true`|
|`--ip-address`|The IP address to use. Also used for the Kubernetes API.|-|`192.168.0.100`|When `--configure-tcpip` is `true` or when there is more than one IP address found.|
|`--netmask`|The netmask to use.|-|`255.255.255.0`|When `--configure-tcpip` is `true`|
|`--default-gateway`|The default gateway to use.|-|`192.168.0.1`|When `--configure-tcpip` is `true`|
|`--dns-servers`|The DNS servers to use.|`"8.8.8.8 4.4.4.4"`|`"192.168.0.2 192.168.0.3"`|No|
|`--dns-search`|The local DNS search domains.|`"domain.local"`|`"example.com domain.internal"`|No|
|`--k8s-cluster-name`|The name given to the cluster.|`kubernetes`|`cluster01`|No|
|`--k8s-version`|The version of Kubernetes to install.|`latest`|`1.25.0-00`|No|
|`--k8s-pod-network-cidr`|The CIDR for pod network.|`10.244.0.0/16`|`10.244.0.0/16`|No|
|`--k8s-service-cidr`|The CIDR for services.|`10.96.0.0/12`|`10.96.0.0/12`|No|
|`--k8s-load-balancer-ip-range`|The IP range or CIDR for Kubernetes load balancer.|-|`192.168.0.10-192.168.0.15`<br>or<br>`192.168.0.1/24`|Yes|
|`--k8s-cni`|The Kubernetes network plugin to install.|`flannel`|`cilium` or `none`|No|
|`--k8s-allow-master-node-schedule`|Set to `true` to allow master node to schedule pods.|`true`|`false`|No|
|`--k8s-kubeadm-options`|Additional options to pass into the `kubeadm init` command.|-|`"--ignore-preflight-errors=all"`|No|
|`--k8s-kubeadm-config`|Kubeadm config file to pass into `kubeadm init --config <file>`.|-|`"/path/to/config.yaml"`|No|
|`--nfs-install-server`|Set to `true` to install NFS server.|`true`|`false`|No|
|`--nfs-server`|The NFS server to use.|`$HOSTNAME`|`192.168.0.100`|When `--nfs-install-server` is `true`|
|`--nfs-share-path`|The NFS share path to use.|`/shares/nfs`|`/mnt/nfs`|When `--nfs-install-server` is `true`|
|`--nfs-default-storage-class`|Set to `true` to use NFS as the default storage class.|`false`|`true`|No|
|`--smb-install-server`|Set to `true` to install SMB server.|`true`|`false`|No|
|`--smb-server`|The SMB server to use.|`$HOSTNAME`|`192.168.0.100`|When `--smb-install-server` is `true`|
|`--smb-share-path`|The SMB share path to use.|`/shares/smb`|`/mnt/smb`|When `--smb-install-server` is `true`|
|`--smb-share-name`|The name of the SMB share.|`persistentvolumes`|`pv`|When `--smb-install-server` is `true`|
|`--smb-username`|The username for the SMB share.|`$SUDO_USER`|`benjamin`|No|
|`--smb-password`|The password for the SMB share.|`password`|`password123`|No|
|`--smb-default-storage-class`|Set to `true` to use SMB as the default storage class.|`true`|`false`|No|
|`--flux-install`|Set to `true` to install and bootstrap flux.|`false`|`true`|No|
|`--flux-git-host`|The hostname of your git server.|`github.com`|`bitbucket.org`|When `--flux-install` is `true`.|
|`--flux-git-org`|Organisation i.e. your GitHub org or username.|-|`7wingfly` or `mycorp`|When `--flux-install` is `true`.|
|`--flux-git-repo`|Name of the git repo.|-|`GitOps`|When `--flux-install` is `true`.|
|`--flux-git-branch`|Branch to work from.|`main`|`master`|When `--flux-install` is `true`.|
|`--flux-git-path`|Directory in repo for the clusters configuration files.|`clusters/<cluster_name>` if `--k8s-cluster-name` is used otherwise `clusters/<hostname>`|`clusters/prod-ukwest-01`|No|
|`--flux-git-auth-method`|The method by which Flux should authenticate to your git server.|-|`ssh` or `https`|When `--flux-install` is `true`.|
|`--flux-git-ssh-private-key-file`|Path to your private key file.|-|`/path/to/key.pem`|When `--flux-git-auth-method` is `ssh`.|
|`--flux-git-ssh-private-key-password`|Password for your private key file if required.|-|`password123`|If the private key file has a password.|
|`--flux-git-https-username`|Username for git server.|-|`7wingfly`|When `--flux-git-auth-method` is `https`.|
|`--flux-git-https-password`|Password or PAT token of git account.|-|`github_pat_<token>`|No|
|`--flux-git-https-use-token-auth`|Adds `--token-auth=true` to bootstrap command.|`false`|`true`|When `--flux-git-auth-method` is `https` and `--flux-git-https-use-bearer-token` is `false`|
|`--flux-git-https-use-bearer-token`|Adds `--with-bearer-token` to bootstrap command.|`false`|`true`|When `--flux-git-auth-method` is `https` and `--flux-git-https-use-token-auth` is `false`|
|`--flux-git-https-ca-file`|Specifies CA certificate file to use when accessing self-hosted git server.|-|`/path/to/ca.crt`|No|
|`--flux-options`|Additional options to pass into the `flux bootstrap git` command.|-|`"--allow-insecure-http"`|No|
<br>

## Notes

### Persistent Volumes

To use an existing NFS and/or SMB file server for [PersistentVolumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) (Instead of using the master node as a file server), simply set `--smb-install-nfs` or `--smb-install-smb` to false and set `--nfs-server` or `--smb-server` to the host name or IP address of your existing file server. For SMB you will need to provide the credentials with `--smb-username` and `--smb-password` as well.

Applying these options will install the NFS and/or SMB CSI driver(s) and create [StorageClass(es)](https://kubernetes.io/docs/concepts/storage/storage-classes/) configured to use your existing file server for Persistent Volumes.

### Control-Plane (Master) Node Scheduling

If you set `--k8s-allow-master-node-schedule` to `false` it will not be possible to deploy any workloads until a worker node has joined the cluster. This includes MetalLB (the load-balancer used to give make your cluster accessible from your local network). You can enable or disable scheduling after installation with these `kubectl` commands.
```bash
# Enable
kubectl taint node $HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule-

# Disable
kubectl taint node $HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule
```

### Host Network DNS Servers

If you add more than 3 DNS servers to the host TCP/IP settings, Kubernetes will display errors about exceeding the nameserver limit. While this will not prevent anything from working, the error messages can be annoying and Kubernetes will only use the first three anyway so you should aim to keep it between 1 and 3.

## Parameter Examples

<br>
Example Usage - Minimum Required:

```bash
./setup_master_node.sh \
    --k8s-load-balancer-ip-range 192.168.0.20-192.168.0.29
```
<p style="width=100%; text-align: center; font-style: italic">Or if your server has more than one IP address</p>

```bash
./setup_master_node.sh \
    --ip-address 192.168.0.230 \
    --k8s-load-balancer-ip-range 192.168.0.20-192.168.0.29
```

<br>
Example Usage - TCP/IP Setup:

```bash
./setup_master_node.sh \
    --configure-tcpip true \
    --interface ens160 \
    --ip-address 192.168.0.230 \
    --netmask 255.255.255.0 \
    --default-gateway 192.168.0.1 \
    --dns-servers "192.168.0.30 192.168.0.31 8.8.8.8" \
    --dns-search "domain1.local domain2.local" \
    --k8s-load-balancer-ip-range 192.168.0.20-192.168.0.29    
```

<br>
Example Usage - Remote NFS Server:

```bash
./setup_master_node.sh \  
    --nfs-install-server false \
    --nfs-server file-server.domain1.local \
    --nfs-default-storage-class true \
    --k8s-load-balancer-ip-range 192.168.0.1/24
```

<br>
Example Usage - Remote SMB Server:

```bash
./setup_master_node.sh \
    --smb-install-server false \
    --smb-server file-server.domain1.local \
    --smb-share-name pvcs \
    --smb-username user \
    --smb-password pass \
    --smb-default-storage-class true \
    --k8s-load-balancer-ip-range 192.168.0.1/24
```

<br>
Example Usage - No Storage (No CSI drivers or Storage Classes will be installed)

```bash
./setup_master_node.sh \  
    --nfs-install-server false \
    --smb-install-server false \
    --k8s-load-balancer-ip-range 192.168.0.1/24
```

<br>
Example Usage - Additional kubeadm init options

```bash
./setup_master_node.sh \  
    --k8s-kubeadm-options "--ignore-preflight-errors=all" \
    --k8s-load-balancer-ip-range 192.168.0.1/24
```
> **IMPORTANT:**
> - **Do not** include `--apiserver-advertise-address`, `--pod-network-cidr` or `--service-cidr` as these are already set in the script. 
> - **Do not** include `--config` as this conflicts with the above. You should instead use `--k8s-kubeadm-config` to pass in your config file.
> - Note that `--k8s-kubeadm-config` and `--k8s-kubeadm-options` used together may cause errors during initialization.
>
> Available options for `kubeadm init` [here](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/).

<br>
Example Usage - Kubernetes CNI

```bash
./setup_master_node.sh \  
    --k8s-cni cilium \
    --k8s-load-balancer-ip-range 192.168.0.1/24
```
> Currently the options are `flannel`, `cilium` or `none`. If you choose `none`, MetalLB will also be skipped, and your control-plane node will be in a `NotReady` state until you install your own CNI.

<br>
Example Usage - Flux CD

_The below are examples of using Flux with a GitHub repository. Options are available for other Git providers. Please read the arguments above in conjunction with the official Flux documentation: https://fluxcd.io/flux/cmd/flux_bootstrap_git/_

With SSH private key file:

```bash
./setup_master_node.sh \
    --k8s-load-balancer-ip-range 192.168.0.1/24 \
    --flux-install true \
    --flux-git-org MyCorp \
    --flux-git-repo GitOps \
    --flux-git-auth-method ssh \
    --flux-git-ssh-private-key-file /your/private/key.pem    
```
This requires uploading your public key to https://github.com/settings/ssh/new

With PAT token:
```bash
./setup_master_node.sh \
    --k8s-load-balancer-ip-range 192.168.0.1/24 \
    --flux-install true \
    --flux-git-org MyCorp \
    --flux-git-repo GitOps \
    --flux-git-auth-method https \
    --flux-git-https-use-token-auth true
    --flux-git-https-username benjamin \
    --flux-git-https-password github_pat_<yourtoken>
```
This requires creating a PAT token at https://github.com/settings/personal-access-tokens.<br>Make sure the token has permissions to read and write content over your repo.

> **NOTE:**<br>
> Autok8s will automatically choose a directory name for your cluster as `clusters/<cluster_name>` where `<cluster_name>` is taken from `--k8s-cluster-name` if specified or the local hostname if not.
>
> You can override this behavior by passing the full directory with `--flux-git-path clusters/mycluster`.

<br>
Example Usage - All:

```bash
./setup_master_node.sh \
    --configure-tcpip true \
    --interface ens160 \
    --ip-address 192.168.0.230 \
    --netmask 255.255.255.0 \
    --default-gateway 192.168.0.1 \
    --dns-servers "192.168.0.30 192.168.0.31 8.8.8.8" \
    --dns-search "domain1.local domain2.local" \
    --k8s-version 1.26.0-00 \
    --k8s-load-balancer-ip-range 192.168.0.20-192.168.0.29 \
    --k8s-cni cilium \
    --k8s-allow-master-node-schedule true \
    --k8s-kubeadm-options "--ignore-preflight-errors=all" \
    --nfs-install-server true \
    --nfs-server srv-k8s-master.domain1.local \
    --nfs-share-path /some/path/nfs \
    --nfs-default-storage-class true \
    --smb-install-server true \
    --smb-server srv-k8s-master.domain1.local \
    --smb-share-path /some/path/smb \
    --smb-share-name pvcs \
    --smb-username user \
    --smb-password pass \
    --smb-default-storage-class false \
    --flux-install true \
    --flux-git-org MyCorp \
    --flux-git-repo GitOps \
    --flux-git-auth-method https \
    --flux-git-https-use-token-auth true
    --flux-git-https-username benjamin \
    --flux-git-https-password github_pat_<yourtoken>
```