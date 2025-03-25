# Autok8s (Automatic Kubernetes)

Autok8s aims to fully automate the installation of self-hosted Kubernetes clusters in a bare-metal or virtual machine based environment. 

This will be of interest to anyone wanting to try out Kubernetes for the first time without spending any money, k8s enthusiasts/profesionals that want a cluster at home for free, or those who are familiar with cloud offerings such as EKS or AKS but would like to learn more about how Kubernetes works under the hood. This may also help those looking to create an on-premis or entirely spot instance cluster in a professional environment.

In managed Kubernetes services such as EKS, AKS or GKE, the control-plane (master) node is abstracted away from you. For self-hosted clusters though, you have to create the control-plane node yourself. There are plenty of great articles out there on how to do this, but the process is not arbitrary. It can take a long time to get working and involves quite a bit of manual work. 

This project aims to fully automate the installation and configuration of a Kubernetes control-plane node along with the worker nodes with no more than one command per node. It includes manifests and Helm charts for pod networking, a load balancer & persistent storage.

In short, the idea of Autok8s is to run a script, wait a few minutes, and have a fully functional, ready to go Kubernetes cluster, just as you would have in the cloud.

Here's a video that demonstrates a brand-new 2 node cluster being created in just over 5 minutes.

[![Self-Hosted Kubernetes Cluster in 5 Minutes](https://user-images.githubusercontent.com/13077550/223282256-3fd23787-94a8-4789-bbeb-8e47c8963a7e.png)](https://www.youtube.com/watch?v=KK3W76xrN9E "Self-Hosted Kubernetes Cluster in 5 Minutes")

## What Does This Do?

### Master (Control-Plane) Node Script:

Here's a high-level overview of the steps `setup_master_node.sh` will perform:

- Performs validation to ensure the hardware meets the minimum requirements and checks that parameter values are valid.

- Configure TCP/IP settings including DNS servers and search domains. (Optional. Added for convenience and time saving).

- Installs prerequisite packages such as `apt-transport-https`, `ca-certificates`, etc.  

- Adds Docker and Kubernetes repositories.

- Installs Docker CE and containerd, then applies required configuration for Kubernetes.

- Installs Kubernetes packages.

- Configures prerequisites such as disabling swap and enabling IPv4 packet forwarding

- Initializes Kubernetes with the `kubeadm init` command.

- Creates the `~/.kube/config` files so you can use `kubectl` as soon as its finished.

- Installs Flannel CNI. (Can be disabled with `--k8s-cni none`)

- Installs Helm.

- Installs NFS file server on the host, NFS CSI drivers via Helm chart, and adds storage class.

    (This is entirely optional and not recommended for production use. It's mainly for those that want a working storage solution out of the box).

- Installs SMB file server on the host, SMB CSI drivers via Helm chart, and adds storage class.

    (Again this is optional. You can also specify an existing SMB and/or NFS server to use rather than make the master node a file server).

- Installs MetalLB via Helm chart (Requires that you reserve a range of IP addresses on your local network to be used by Kubernetes [services](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) of type `LoadBalancer`).

- Prints a message containing the command and parameters for joining a node to the cluster using the AutoK8s `setup_worker_node.sh` script.

Once your master node is up and running you can use the manifests found in the [TestManifests/Storage](https://github.com/7wingfly/autok8s/tree/main/TestManifests/Storage) directory to test out NFS and SMB and storage. In the near future other manifests will be added for things like networking.

### Worker Node Script:

Here's a high-level overview of the steps `setup_worker_node.sh` will perform:

- Performs validation to ensure the hardware meets the minimum requirements and checks that parameter values are valid.

- Configure TCP/IP settings including DNS servers and search domains. (Optional. Added for convenience and time saving).

- Installs prerequisite packages such as `apt-transport-https`, `ca-certificates`, etc.  

- Adds Docker and Kubernetes repositories.

- Installs Docker CE and containerd, then applies required configuration for Kubernetes.

- Installs Kubernetes packages.

- Configures prerequisites such as disabling swap and enabling IPv4 packet forwarding

- Joins the Kubernetes cluster using the `kubeadm join` command.

## Getting Ready!

The minimum hardware requirements for a Kubernetes node is 2 CPU's and 1,700 MB of RAM. If your hardware does not meet these requirements the Autok8s scripts will not proceed.

It's highly recommended that you run this on a brand new Ubuntu 20.04 server virtual machine. When you install the Ubuntu OS and are presented with the list of optional packages to install, **DO NOT** select docker. This will install the `docker.io` package which is no longer compatible with Kubernetes. This script will install the `docker-ce` package for you instead.

If you run this on a VM and have the ability to take a snapshot before you start, it is recommended you do so because if the script fails or if you want to do it again with different options then running the script more than once may have unexpected results. 

There a quite a few paramters you can pass into the script. At the very least you will need to provide the IP range for the load balancer. The IP range should be outside of your DHCP scope, or alternatively DHCP reservations should be made to ensure you do not have IP address conflicts between the [services](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) in Kubernetes and other devices on your local network.

It's recommended to read the Master Node Parameters [document](https://github.com/7wingfly/autok8s/tree/main/NodeParameters_Master.md) for details on all available parameters before you begin.

## Go Time!
You can run the `setup_master_node.sh` script in one of two ways. Download or copy & paste the script directly from [here](https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_master_node.sh), give it execute permissions and run it as `sudo`.

```
sudo chmod +x ./setup_master_node.sh
sudo ./setup_master_node.sh --k8s-load-balancer-ip-range <IP range or CIDR>
```

Or you can run it straight from GitHub using the `curl` command as follows:

```
curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_master_node.sh | sudo bash -s -- \
    --k8s-load-balancer-ip-range <IP range or CIDR>
```

Note that if your server has more than one IP address you will need to specify which to use for the Kubernetes Server API. The script will not proceed if more than one is detected.

```
curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_master_node.sh | sudo bash -s -- \
    --ip-address <master node IP> \
    --k8s-load-balancer-ip-range <IP range or CIDR>
```

The installation can take a fairly long time depending on your hardware and internet speed. Allow for around 30 minutes on slower internet connections and/or hardware.

Once installation is complete the following message will be shown detailing the command for joining worker nodes to your cluster using the `setup_worker_node.sh` script as well as some other tips and useful infomation.

![complete-message](https://user-images.githubusercontent.com/13077550/222972633-63b91c73-e922-486a-9025-9ae78a630175.JPG)

The `setup_worker_node.sh` script also has several parameters you can use to configure the worker nodes as needed. Read the Worker Node Parameters [document](https://github.com/7wingfly/autok8s/tree/main/NodeParameters_Worker.md) for details on all available parameters before you begin.

As shown earlier in the success message, the `setup_worker_node.sh` command can also be ran from GitHub using the `curl` command:

```
curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/setup_worker_node.sh | sudo bash -s -- \
    --k8s-master-ip <master node IP> \
    --k8s-master-port 6443 \
    --token <token> \
    --discovery-token-ca-cert-hash <ca cert hash> 
```

Lastly, run the `cat ~/.kube/config` command on the control-plane node, copy the kube config and save to `.kube/config` under your home directory on your local machine to use `kubectl` or a Kubernetes IDE such as [Lens](https://k8slens.dev/).

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
