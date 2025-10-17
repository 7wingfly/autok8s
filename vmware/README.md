# <t style="color: #dd54ffff">Auto</t><t style="color: #49aeddff">k8s</t> | VMware Setup

The Autok8s VMware Setup scripts included in this directory aim to automate the installation and configuration of VMware vSphere CSI ([Container Storage Interface](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/)) and CPI ([Cloud Provider Interface](https://cloud-provider-vsphere.sigs.k8s.io/cloud_provider_interface.html); a [CCM](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)) on an existing Kubernetes cluster running in a VMware vSphere environment.

---

### VMware vSphere CSI driver: 
The VMware vSphere CSI driver enables dynamic provisioning of storage volumes via Kubernetes Storage Classes and the vCenter API. In short: when you create a PersistentVolumeClaim (PVC) with a StorageClass using the `csi.vsphere.vmware.com` provisioner, the CSI driver creates a virtual disk (VMDK) in the [Datastore](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere/6-5/vsphere-storage-6-5/working-with-datastores-in-vsphere-storage-environment/vsphere-vmfs-datastore-concepts-and-operations.html) specified in the StorageClass, and when that PVC is mounted to a Pod, the CSI driver attaches the virtual disk to the virtual machine (Kubernetes node) that the Pod has been scheduled on.

Read more about the CSI driver here:<br>https://github.com/kubernetes-sigs/vsphere-csi-driver

---

### VMware vSphere CPI driver:
The VMware vSphere CPI driver is the Cloud Controller Manager ([CCM](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)) for vSphere. It's responsible for updating node objects in Kubernetes with details of the underlying virtual machines on which the nodes are running. For example, the CPI driver will find the VM for each node in vCenter and update each node's `spec.providerID` to `vsphere://<VM-UUID>`, the `status.addresses` list (e.g. `InternalIP`), and adds topology labels `topology.kubernetes.io/region` and `topology.kubernetes.io/zone`, with values derived from the VM's tags, which the CSI driver can use for topology-aware provisioning. It will also remove node objects from Kubernetes when VMs are deleted.

Read more about the CPI driver here:<br>
https://cloud-provider-vsphere.sigs.k8s.io/concepts/cpi_overview

## What does this do?

### Master (Control-Plane) Node VMware Script:

Here's a high-level overview of the steps `vmware_setup_master_node.sh` will perform:

**Preparation:**

- Downloads and installs [govc](https://github.com/vmware/govmomi), a CLI utility for interacting with vCenter. (Required for setup only, not needed by CSI/CPI drivers)

- Authenticates to vCenter and checks the user account group membership (`Administrators` by default).

- Finds its own virtual machine in vCenter via its IP address, then fetches its unique ID and assigned tags and their tag categories.

**vSphere CSI driver:**

- Checks that the VMware hardware version is 15 or above.

- Checks that a SCSI controller of type `VMware Paravirtual` is installed.

- Applies the advanced setting `disk.EnableUUID=TRUE` if not already set.

- Attempts to find the specified Datastore(s) for which to create Storage Classes, or if unspecified, enumerates all Datastores.

- Creates the namespace `vmware-system-csi`

- Pulls and applies the latest version (unless specified) of CSI driver manifests from GitHub.

- Creates a `vsphere-config-server` Secret containing a config file that specifies the credentials and datacenter name(s) for vCenter.

- Enumerates over the list of successfully checked Datastore(s) from earlier and creates two Storage Classes for each one, one with a `retain` reclaim policy and another with `Delete`.

**vSphere CPI driver:** *(Optional)*

- Checks to see if the specified tags are set on the VM. If they are not, they will be applied. If they do not exist, they will be created along with their tag categories if also absent. Different tags belonging to the same category will be removed if present. (This behavior can be disabled).

- Creates the namespace `vmware-system-cpi`

- Creates a `vsphere-cloud-secret` Secret containing the vCenter credentials (same used for CSI).

- Creates a `cloud-config` ConfigMap containing a YAML config file that specifies:

  - vCenter address.
  - Datacenter name.  
  - Name of the Secret containing the credentials.
  - A map of Kubernetes labels (`region` and `zone`) and their corresponding vCenter tag categories (by default: `k8s-region` and `k8s-zone`).    

- Installs the CPI driver via Helm.

- Taints all nodes with `node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule`<br> (The CPI driver will only update nodes with this taint).

### Worker Node VMware Script:

The worker script is not required for a successful deployment of the CSI or CPI drivers to the cluster; its purpose is to check and configure the VMs with the correct settings and tags if not already set up. If your VMs already meet the requirements, you can skip this script.

Here's a high-level overview of the steps `vmware_setup_worker_node.sh` will perform:

- Downloads and installs [govc](https://github.com/vmware/govmomi), a CLI utility for interacting with vCenter. (Required for setup only, not needed by CSI/CPI drivers)

- Authenticates to vCenter and checks the user account group membership (`Administrators` by default).

- Finds its own virtual machine in vCenter via its IP address, then fetches its unique ID and assigned tags and their tag categories.

- Checks that the VMware hardware version is 15 or above.

- Checks that a SCSI controller of type `VMware Paravirtual` is installed.

- Applies the advanced setting `disk.EnableUUID=TRUE` if not already set.

- Checks to see if the specified tags are set on the VM. If they are not, they will be applied. If they do not exist, they will be created along with their tag categories if also absent. Different tags belonging to the same category will be removed if present. (This step is optional).

## Getting Ready!
In order to use the CSI and CPI drivers you must meet the following requirements:

- A physical or virtual machine running ESXi 7.0 U3 or later

- VMware vCenter 7.0 U3 or later (for full CSI/CNS feature coverage, keep vCenter and all ESXi hosts on the same major/minor version)

- Virtual Machine(s) running Kubernetes with:
  - VM hardware version 15 or above
  - VMware Paravirtual SCSI storage controller
  - VMware Tools installed
  - The flag `disk.EnableUUID=TRUE` (Autok8s will attempt to add this if absent)

- Kubernetes: Use a CSI version [compatible](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0/vsphere-container-storage-plug-in-concepts/compatibility-matrix-for-vsphere-container-storage-plug-in.html) with your Kubernetes minor version.
- A vCenter user account with which CSI and CPI drivers can authenticate. Must have the required [roles](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0/vsphere-container-storage-plug-in-deployment/preparing-for-installation-of-vsphere-container-storage-plug-in.html#GUID-043ACF65-9E0B-475C-A507-BBBE2579AA58-en) assigned. (For testing/simplicity use the `Administrator` role)
 
See more about compatibility and requirements [here](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0/vsphere-container-storage-plug-in-concepts/compatibility-matrix-for-vsphere-container-storage-plug-in.html) and [here](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0/vsphere-container-storage-plug-in-deployment/preparing-for-installation-of-vsphere-container-storage-plug-in.html?utm_source).

> [!NOTE]
> If you have not yet created your Kubernetes cluster and you intend to install the CPI drivers post-installation, it is highly recommended that you include the argument `--k8s-cloud-provider external` when running the master and worker node scripts. 
>
> This will apply extra kubelet arguments (affecting how Kubernetes is configured), apply the taint required by the CCM (vSphere CPI), and include taint tolerations on CoreDNS, the CNI, MetalLB, SMB and NFS CSI drivers, and other core components.

It's recommended to read the VMware Master Node Parameters [document](https://github.com/7wingfly/autok8s/tree/main/vmware/VMwareParameters_Master.md) for details on all available parameters before you begin.

## Go Time!

You can run the `vmware_setup_master_node.sh` script in one of two ways. Download or copy & paste the script directly from [here](https://raw.githubusercontent.com/7wingfly/autok8s/main/vmware/vmware_setup_master_node.sh), give it execute permissions and run it as `sudo`.

```
sudo chmod +x ./vmware_setup_master_node.sh
sudo ./vmware_setup_master_node.sh \
    --vcenter-host <vcenter_host_address> \
    --vcenter-username <vcenter_username> \
    --vcenter-password <vcenter_password> \
    --vcenter-insecure <true|false> \
    --vsphere-cpi-tag-region <region, e.g. UK> \
    --vsphere-cpi-tag-zone <zone, e.g. Engineering>
```

Or you can run it straight from GitHub using the `curl` command as follows:

```
curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/vmware/vmware_setup_master_node.sh | sudo bash -s -- \
    --vcenter-host <vcenter_host_address> \
    --vcenter-username <vcenter_username> \
    --vcenter-password <vcenter_password> \
    --vcenter-insecure <true|false> \
    --vsphere-cpi-tag-region <region, e.g. UK> \
    --vsphere-cpi-tag-zone <zone, e.g. Engineering>    
```

If successful, the script should complete in only a few minutes. Once the script is complete, it may take a minute or two for the CPI driver to update the nodes and remove the taints. 

If you are retrospectively running this script on an existing cluster where the `--k8s-cloud-provider` parameter was not used, please note the following:

- The taint will prevent the scheduling of all new Pods until removed by the CPI driver. Therefore it's recommended to add tolerations to all critical Pods before executing this script. This includes some system Pods like CoreDNS and some CNIs like Cilium.

- The worker node script is unable to apply the taint to itself, therefor it's recommended that you run the worker node script first on each worker node, and then the master node script, which will taint all of the nodes at the end. 

- If you add new nodes to the cluster, ensure you specify `--k8s-cloud-provider external` when running autok8s, or manually add the `node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule` taint to the node after it joins the cluster.

## Links

Container Storage Interface (CSI) for Kubernetes
<br>
https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/

vSphere CSI driver source
<br>
https://github.com/kubernetes-sigs/vsphere-csi-driver

VMware vSphere Container Storage Plug-in 3
<br>
https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0.html

Kubernetes vSphere Cloud Provider
<br>
https://cloud-provider-vsphere.sigs.k8s.io

Kubernetes Cloud Controller Manager
<br>
https://kubernetes.io/docs/concepts/architecture/cloud-controller
