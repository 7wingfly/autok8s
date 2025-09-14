# Worker Node Parameters
The following is a list of all available parameters you can use with the `setup_worker_node.sh` script. At the bottom are some examples that can help you get started and some notes on things to watch out for when setting some of the parameter values. 

Parameter values which are wraped in quotes must include the quotes when applied.

Parameters that have default values but are marked as required can still be ommited from the command line. In this event the default value will be used.

<br>
<br>

|Parameter Name|Description|Default Value|Example Value|Required|
|--- |--- |--- |--- |--- |
|`--configure-tcpip`|Set to `true` to configure TCP/IP settings of this server.|`false`|`true`|No|
|`--interface`|The interface to configure IP settings for.|`eth0`|`ens160`|When `--configure-tcpip` is `true`|
|`--ip-address`|The IP address to use.|-|`192.168.0.100`|When `--configure-tcpip` is `true`|
|`--netmask`|The netmask to use.|-|`255.255.255.0`|When `--configure-tcpip` is `true`|
|`--default-gateway`|The default gateway to use.|-|`192.168.0.1`|When `--configure-tcpip` is `true`|
|`--dns-servers`|The DNS servers to use.|`"8.8.8.8 4.4.4.4"`|`"192.168.0.2 192.168.0.3"`|No|
|`--dns-search`|The local DNS search domains.|`"domain.local"`|`"example.com domain.internal"`|No|
|`--k8s-version`|The version of Kubernetes to install.|`latest`|`1.25.0-00`|No|
|`--k8s-master-ip`|The IP address of the control-plane node.|-|`192.168.0.10`|Yes|
|`--k8s-master-port`|The Kubernetes API server port on the control-plane node.|`6443`|`6443`|Yes|
|`--k8s-kubeadm-options`|Additional options to pass into the `kubeadm join` command.|-|`"--ignore-preflight-errors=all"`|No|
|`--token`|The `token` portion of the `kubeadm join` command.|-|`kspnlk.7h[..]3f`|Yes|
|`--discovery-token-ca-cert-hash`|The `discovery-token-ca-cert-hash` portion of the `kubeadm join` command.|-|`sha256:68d[..]bb2`|Yes|

<br>

## Notes

The `--token` and `--discovery-token-ca-cert-hash` parameters should be exactly the same as the output from the `kubeadm join` command. To obtain these values again run `kubeadm token create --print-join-command` on the control-plane (master) node.

## Parameter Examples

<br>
Example Usage - Minimum Required:

```bash
./setup_worker_node.sh \
    --k8s-master-ip 192.168.0.230 \    
    --token fbdzi9.5yedbdve20r \
    --discovery-token-ca-cert-hash sha256:68d0860434a20c9eb533b640f23134c0fdacc4b929e97c8f8e537f9b4befabb2 
```

<br>
Example Usage - Additional kubeadm join options

```bash
./setup_master_node.sh \  
    --k8s-kubeadm-options "--ignore-preflight-errors=all" 
```
> Available options for `kubeadm join` [here](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/). <br> **Do not** include `--token` or `--discovery-token-ca-cert-hash` as these are already set in the script.

<br>
Example Usage - All:

```bash
./setup_worker_node.sh \
    --configure-tcpip true \
    --interface ens160 \
    --ip-address 192.168.0.231 \
    --netmask 255.255.255.0 \
    --default-gateway 192.168.0.1 \
    --dns-servers "192.168.0.30 192.168.0.31 8.8.8.8" \
    --dns-search "domain1.local domain2.local" \
    --k8s-master-ip 192.168.0.230 \
    --k8s-master-port 6443 \
    --k8s-kubeadm-options "--ignore-preflight-errors=all" \
    --token fbdzi9.5yedbdve20r \
    --discovery-token-ca-cert-hash sha256:68d0860434a20c9eb533b640f23134c0fdacc4b929e97c8f8e537f9b4befabb2 
```