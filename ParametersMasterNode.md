# Master Node Parameters
The following is a list of all available parameters you can use with the `setup_master_node.sh`. 

|Parameter Name|Description|Default Value|Example Value|Required|
|--- |--- |--- |--- |--- |
|`--configure-tcpip`|Set to `true` to configure TCP/IP settings of this server.|`false`|true|No|
|`--interface`|The interface to configure IP settings for.|`eth0`|`ens160`|When `--configure-tcpip` is `true`|
|`--ip-address`|The IP address to use.||`192.168.0.100`|Yes|
|`--netmask`|The netmask to use.||`255.255.255.0`|When `--configure-tcpip` is `true`|
|`--default-gateway`|The default gateway to use.||`192.168.0.1`|When `--configure-tcpip` is `true`|
|`--dns-servers`|The DNS servers to use.|`"8.8.8.8 4.4.4.4"`|"192.168.0.2 192.168.0.3"|No|
|`--dns-search`|The local DNS search domains.|`"domain.local"`|`"example.com domain.internal"`|No|
|`--k8s-version`|The version of Kubernetes to install.|`latest`|`1.25.0-00`|No|
|`--k8s-load-balancer-ip-range`|The IP range or CIDR for Kubernetes load balancer.||`192.168.0.10-192.168.0.15`<br>or<br>`192.168.0.1/24`|No|
|`--k8s-allow-master-node-schedule`|Set to true to allow master node to schedule pods.|true|false|No|
|`--nfs-install-server`|Set to `true` to install NFS server.|true|false|No|
|`--nfs-server`|The NFS server to use.|`$HOSTNAME`|`192.168.0.100`|When `--nfs-install-server` is `true`|
|`--nfs-share-path`|The NFS share path to use.|`/shares/nfs`|`/mnt/nfs`|When `--nfs-install-server` is `true`|
|`--nfs-default-storage-class`|Set to `true` to use NFS as the default storage class.|`false`|`true`|No|
|`--smb-install-server`|Set to `true` to install SMB server.|`true`|`false`|No|
|`--smb-server`|The SMB server to use.|`$HOSTNAME`|`192.168.0.100`|When `--smb-install-server` is `true`|
|`--smb-share-path`|The SMB share path to use.|`/shares/smb`|`/mnt/smb`|When `--smb-install-server` is `true`|
|`--smb-share-name`|The name of the SMB share.|`persistentvolumes`|`pv`|When `--smb-install-server` is `true`|
|`--smb-username`|The username for the SMB share.|`$SUDO_USER`|`john`|No|
|`--smb-password`|The password for the SMB share.|`password`|`mypass`|No|
|`--smb-default-storage-class`|Set to `true` to use SMB as the default storage class.|`true`|`false`|No|
<br>

## Notes

For both the NFS and SMB storage options. Setting `--smb-install-<type>` to `false` and setting `--<type>-server` to the hostname of your file server will result in the CSI drivers being installed and a storage class being created configured to communicate with the remote server. For this to work the appropriate permissions must be granted on the folder / share, and for SMB valid credentials must be specified.

If you set `--k8s-allow-master-node-schedule` to `false` it will not be possible to deploy any workloads until a worker node has joined the cluster. This includes MetalLB (the load-balancer used to give make your cluster accessible from your local network). You can enable or disable scheduling after installation with these `kubectl` commands
```
# Enable
kubectl taint node $HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule-

# Disable
kubectl taint node $HOSTNAME node-role.kubernetes.io/control-plane:NoSchedule
```

If you add more than 3 DNS servers to the host TCP/IP settings, Kubernetes will display errors relating to exceeding the nameserver limit. While this will not stop anything from work, the error messages can be annoying and Kubernetes will only use the first three anyway so you should aim to keep it between 1 and 3.

## Parameter Examples

<br>
Example Usage - Minimum Required:

```
./setup_master_node.sh \
    --ip-address 192.168.0.230 \
    --dns-servers "192.168.0.30 192.168.0.31 8.8.8.8"
```

<br>
Example Usage - TCP/IP Setup:

```
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

```
./setup_master_node.sh \
    --ip-address 192.168.0.230 \
    --dns-servers "192.168.0.30 192.168.0.31 8.8.8.8" \
    --nfs-install-server true \
    --nfs-server file-server.domain1.local \
    --nfs-default-storage-class true
```

<br>
Example Usage - Remote SMB Server:

```
./setup_master_node.sh \
    --ip-address 192.168.0.230 \
    --dns-servers "192.168.0.30 192.168.0.31 8.8.8.8" \
    --smb-install-server true \
    --smb-server file-server.domain1.local \
    --smb-share-name pvcs \
    --smb-username user \
    --smb-password pass \
    --smb-default-storage-class true
```

<br>
Example Usage - All:

```
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
    --k8s-allow-master-node-schedule true \
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
    --smb-default-storage-class false    
```