# Autok8s (Automatic Kubernetes)

The idea behind this project is to fully automate the installation of a Kubernetes cluster on bare-metal or virtual machines. The primary target audience for this is k8s nerds that want a full cluster at home for free, but this may also help those looking to create an on-premis or entirely spot instance cluster in a professional environment.

Unlike managed Kubernetes services such as EKS, AKS or GKE, the control-plane (master) node is not abstracted away from you and is something that you have to setup yourself. 

There are plenty of great articles out there on how to do this, but the process is not arbitrary. It can take a long time to get working and involves quite a bit of manual work. 

This project aims to fully automate the installation and configuration of a Kubernetes control-plane node and the worker nodes, and adds Helm charts for the load balancer, persistent storage, etc, once Kubernetes is istalled.

In short, the idea of Autok8s is to run a script, wait 15ish minutes, and have a fully functional and ready to go Kubernetes cluster, just as you would have in the cloud.

## Future Plans

There will be a separate set of scripts for those wanting to make use of the vSphere CPI and CSI drivers, and possibly in the future other drivers or hardware/environments as well. 

This project is very early days and thus far has only been tested on a fresh installation of Ubuntu 20.04 on an older VMware hypervisor (without the CPI and CSI drivers). In the future more testing will be performed to ensure it works as expected in any environment. If you do run this script on a different environment, please let me know your findings and feel free to create pull requests.

## What Does This Do?

Here's a high-level overview of the steps `setup_aks_master.sh` will perform:

- Configure TCP/IP settings including DNS servers and search domains. (Optional. Added for convenience and time saving).

- Installs prerequisite packages such as `apt-transport-https`, `ca-certificates`, etc.  

- Adds Docker and Kubernetes repositories.

- Installs Docker CE and containerd, then applies required configuration for Kubernetes.

- Installs Kubernetes packages

- Initializes Kubernetes with the `kubeadm` command.

- Creates the `~/.kube/config` files so you can use `kubectl` as soon as its finished.

- Installs Flannel layer 3 networking.

- Installs Helm

- Installs NFS file server on the host, NFS CSI drivers and adds storage class.

    (This is entirely optional and not recommended for production use. It's mainly for those that want a working storage solution out of the box).

- Installs SMB file server on the host, SMB CSI drivers and adds storage class.

    (Again this is optional. You can also specify an existing SMB and/or NFS server to use rather than make the master node a file server).

- Installs MetalLB (For use with home or on-premis networks. Requires that you reserve a range of IP addresses on your local network to be used by Kubernetes service objects).

- Prints a friendly success message at the end with tips on how to connect to your cluster and how to add worker nodes.

Once your master node is up and running you can use the manifests found in the [TestManifests/Storage](https://github.com/7wingfly/autok8s/tree/main/TestManifests/Storage) directory to test out NFS and SMB and storage. In the near future other manifests will be added for things like networking.

## Getting Ready!

It's highly recommended that you run this on a brand new Ubuntu 20.04 virtual machine. When you install the Ubuntu OS and are presented with the list of optional packages to install, DO NOT select docker. This will install the `docker.io` package which is no longer compatible with Kubernetes. This script will install the `docker-ce` package for you instead.

If you run this on a VM and have the ability to take a snapshot before you start, it is recommended you do so because if the script fails or if you want to do it again with different options then running the script more than once may have unexpected results. 

There a quite a few paramters you can pass into the script. At the very least you will need to provide an IP address for the server and the IP range for the load balancer. Both the static IP for the node(s) and the IP range for the load-balancer should be outside of your DHCP scope, or alternatively DHCP reservations should be made to ensure you do not have IP address conflicts between the [services](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) in Kubernetes and other devices on your local network.

You should read he Master Node Parameters [document](https://github.com/7wingfly/autok8s/tree/main/MasterNodeParameters.md) for details on all available parameters before you begin.

## Go Time!
You can run the `setup_master_node.sh` script in one of two ways. Download/copy & paste the script directly from [here](https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_master_node.sh), give it execute permissions and run it as `sudo`.

```
sudo chmod +x ./setup_master_node.sh
sudo ./setup_master_node.sh \
    --ip-address 192.168.0.10 \
    --k8s-load-balancer-ip-range 192.168.0.20-192.168.0.29
```

Or you can run it run it straight from GitHub using the `curl` command as follows:

```
curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_master_node.sh | sudo bash -s -- \
    --ip-address 192.168.0.10 \
    --k8s-load-balancer-ip-range 192.168.0.20-192.168.0.29
```

The installation can take a fairly long time depending on your hardware and internet speed. Allow for a minimum of 30 minutes, but your milage may vary.

Once the installation is complete the following message will be shown detailing the command for joining woker nodes to your cluster as well as some other tips and infomation.

![complete-message](https://user-images.githubusercontent.com/13077550/222903364-967f1c24-f1cb-435c-b136-179a4d123764.JPG)

As the message suggests you can use the `cat ~/.kube/config` command copy your kube config and paste it to your local machine to use with `kubectl` or a Kubernetes IDE such as [Lens](https://k8slens.dev/).

## Links

Links to documentation used to create this project:

Docker install docs:
<br>
https://docs.docker.com/engine/install/ubuntu/

Containerd config:
<br>
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd-systemd

Kubernetes install docs:
<br>
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

Kubeadm init docs:
<br>
https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/


Flannel networking docs:
<br>
https://github.com/flannel-io/flannel/#readme

NFS CSI driver:
<br>
https://github.com/kubernetes-csi/csi-driver-nfs
<br>
https://github.com/kubernetes-csi/csi-driver-nfs/tree/master/charts

SMB CSI driver:
<br>
https://github.com/kubernetes-csi/csi-driver-smb
<br>
https://github.com/kubernetes-csi/csi-driver-smb/tree/master/charts
<br>
https://ubuntu.com/tutorials/install-and-configure-samba#2-installing-samba


MetalLB load balancer 
<br>
https://metallb.universe.tf/installation/
<br>
https://metallb.universe.tf/configuration/_advanced_l2_configuration/
