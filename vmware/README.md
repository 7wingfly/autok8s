# <t style="color: #dd54ffff">Auto</t><t style="color: #49aeddff">k8s</t> | VMware Setup

The Autok8s VMware Setup scripts included in this directory automate the installation and configuration of the VMware vSphere ([Container Storage Interface](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/)) and CPI ([Cloud Provider Interface](https://cloud-provider-vsphere.sigs.k8s.io/cloud_provider_interface.html) — a [CCM](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)) on an existing Kubernetes cluster running in a VMware vSphere environment.

---

### VMware vSphere CSI driver
The VMware vSphere CSI driver enables dynamic provisioning of storage volumes via Kubernetes StorageClasses and the vCenter API. In short: when you create a PersistentVolumeClaim (PVC) with a StorageClass using the `csi.vsphere.vmware.com` provisioner, the CSI driver creates a virtual disk (VMDK) in the [Datastore](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere/6-5/vsphere-storage-6-5/working-with-datastores-in-vsphere-storage-environment/vsphere-vmfs-datastore-concepts-and-operations.html) specified in the StorageClass, and when that PVC is mounted to a Pod, the CSI driver attaches the virtual disk to the virtual machine (Kubernetes node) that the Pod is scheduled on.

Read more about the CSI driver here:
https://github.com/kubernetes-sigs/vsphere-csi-driver

---

### VMware vSphere CPI driver
The VMware vSphere CPI driver is the Cloud Controller Manager ([CCM](https://kubernetes.io/docs/concepts/architecture/cloud-controller/)) for vSphere. It's responsible for updating node objects in Kubernetes with details of the underlying virtual machines on which the nodes are running. For example, the CPI driver finds the VM for each node in vCenter and updates each node's `spec.providerID` to `vsphere://<VM-UUID>`, the `status.addresses` list (e.g. `InternalIP`), and adds topology labels `topology.kubernetes.io/region` and `topology.kubernetes.io/zone`, with values derived from the VM's tags, which the CSI driver can use for topology-aware provisioning. It also removes node objects from Kubernetes when VMs are deleted.

Read more about the CPI driver here:
https://cloud-provider-vsphere.sigs.k8s.io/concepts/cpi_overview

## What does this do?

### Master (Control-Plane) Node VMware Script

Here's a high-level overview of the steps `vmware_setup_master_node.sh` performs:

**Preparation:**

- Downloads and installs [govc](https://github.com/vmware/govmomi), a CLI utility for interacting with vCenter. (Required for setup only; not needed by CSI/CPI drivers).

- Authenticates to vCenter and checks the user account's group membership (`Administrators` by default).

- Finds its own virtual machine in vCenter via its IP address, then fetches its unique ID and assigned tags and tag categories.

**vSphere CSI driver:**

- Checks that the VMware hardware version is 15 or above.

- Checks that a SCSI controller of type `VMware Paravirtual` is installed.

- Applies the advanced setting `disk.EnableUUID=TRUE` if not already set.

- Attempts to find the specified Datastore(s) for which to create StorageClasses, or if unspecified, enumerates all Datastores.

- Creates the namespace `vmware-system-csi`.

- Pulls and applies the latest CSI driver manifests from GitHub (unless a version is specified).

- Creates a `vsphere-config-server` Secret containing a config file that specifies the credentials and datacenter name(s) for vCenter.

- Enumerates the list of successfully checked Datastore(s) and creates two StorageClasses for each one: one with a `retain` reclaim policy and another with `Delete`.

**vSphere CPI driver:** *(Optional)*

- Checks whether the specified tags are set on the VM. If they are not, they will be applied. If they do not exist, they will be created along with their tag categories if also absent. Different tags belonging to the same category will be removed if present. (This behavior can be disabled).

- Creates the namespace `vmware-system-cpi`.

- Creates a `vsphere-cloud-secret` Secret containing the vCenter credentials (the same credentials used for CSI).

- Creates a `cloud-config` ConfigMap containing a YAML config file that specifies:
  - vCenter address.
  - Datacenter name.
  - Name of the Secret containing the credentials.
  - A map of Kubernetes labels (`region` and `zone`) and their corresponding vCenter tag categories (by default: `k8s-region` and `k8s-zone`).

- Installs the CPI driver via Helm.

- Taints all nodes with `node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule` (the CPI driver will only update nodes with this taint).

### Worker Node VMware Script

The worker script is not required to deploy the CSI or CPI drivers to the cluster successfully; its purpose is to check and configure VMs with the correct settings and tags if they are not already configured. If your VMs already meet the requirements, you can skip this script.

Here's a high-level overview of the steps `vmware_setup_worker_node.sh` performs:

- Downloads and installs [govc](https://github.com/vmware/govmomi), a CLI utility for interacting with vCenter. (Required for setup only; not needed by CSI/CPI drivers).

- Authenticates to vCenter and checks the user account's group membership (`Administrators` by default).

- Finds its own virtual machine in vCenter via its IP address, then fetches its unique ID and assigned tags and tag categories.

- Checks that the VMware hardware version is 15 or above.

- Checks that a SCSI controller of type `VMware Paravirtual` is installed.

- Applies the advanced setting `disk.EnableUUID=TRUE` if not already set.

- Checks whether the specified tags are set on the VM. If they are not, they will be applied. If they do not exist, they will be created along with their tag categories if also absent. Different tags belonging to the same category will be removed if present. (This step is optional).

## Getting Ready

To use the CSI and CPI drivers you must meet the following requirements:

- A physical or virtual machine running ESXi 7.0 U3 or later.

- VMware vCenter 7.0 U3 or later (for full CSI/CNS feature coverage, keep vCenter and all ESXi hosts on the same major/minor version).

- Virtual Machines running Kubernetes with:
  - VM hardware version 15 or above.
  - VMware Paravirtual SCSI storage controller.
  - VMware Tools installed.
  - The flag `disk.EnableUUID=TRUE` (Autok8s will attempt to add this if absent).

- Kubernetes: use a CSI version [compatible](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0/vsphere-container-storage-plug-in-concepts/compatibility-matrix-for-vsphere-container-storage-plug-in.html) with your Kubernetes minor version.

- A vCenter user account with which CSI and CPI drivers can authenticate. The account must have the required roles assigned. (For testing/simplicity, use the `Administrator` role).

See more about compatibility and requirements [here](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/container-storage-plugin/3-0/getting-started-with-vmware-vsphere-container-storage-plug-in-3-0/vsphere-container-storage-plug-in-concepts/compatibility-matrix-for-vsphere-container-storage-plug-in.html).

> [!NOTE]
>
> If you have not yet created your Kubernetes cluster and you intend to install the CPI drivers post-installation, it is highly recommended that you include the argument `--k8s-cloud-provider external` when running the master and worker node scripts.
>
> This will apply extra kubelet arguments (affecting how Kubernetes is configured), apply the taint required by the CCM (vSphere CPI), and add taint tolerations to CoreDNS, the CNI, MetalLB, SMB and NFS CSI drivers, and other core components.

It's recommended to read the VMware Master Node Parameters document for details on all available parameters before you begin:
https://github.com/7wingfly/autok8s/tree/main/vmware/VMwareParameters_Master.md

## Go Time!

You can run the `vmware_setup_master_node.sh` script in one of two ways. Download or copy & paste the script directly from [here](https://raw.githubusercontent.com/7wingfly/autok8s/main/vmware/vmware_setup_master_node.sh), give it execute permissions and run it with `sudo`:

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

Or run it directly from GitHub using `curl`:

```
curl -s https://raw.githubusercontent.com/7wingfly/autok8s/main/vmware/vmware_setup_master_node.sh | sudo bash -s -- \
    --vcenter-host <vcenter_host_address> \
    --vcenter-username <vcenter_username> \
    --vcenter-password <vcenter_password> \
    --vcenter-insecure <true|false> \
    --vsphere-cpi-tag-region <region, e.g. UK> \
    --vsphere-cpi-tag-zone <zone, e.g. Engineering>
```

If successful, the script should complete in a few minutes. Once complete, it may take a minute or two for the CPI driver to update the nodes and remove the taints.

If you are retrospectively running this script on an existing cluster where the `--k8s-cloud-provider` parameter was not used, note the following:

- The taint will prevent scheduling of new Pods until removed by the CPI driver. Therefore, add tolerations to all critical Pods before executing this script. This includes some system Pods like CoreDNS and some CNIs like Cilium.

- The worker node script is unable to apply the taint to itself; therefore it's recommended to run the worker node script first on each worker node, and then run the master node script, which will taint all nodes at the end.

- If you add new nodes to the cluster, ensure you specify `--k8s-cloud-provider external` when running autok8s, or manually add the `node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule` taint to the node after it joins the cluster.

## Screenshots

Below are some screenshots of the various stages:

Installing prerequisite tools and validating vCenter user account:

![VMware Data Collection](https://pub-4dac79d0e98d4b6eaa378b38fc71cbf8.r2.dev/autok8s-vmware-readme00.png)

Getting info from vCenter regarding the VM, Datacenter and Datastores:

![VMware Data Collection](https://pub-4dac79d0e98d4b6eaa378b38fc71cbf8.r2.dev/autok8s-vmware-readme01.png)

The creation of Kubernetes StorageClasses from the discovered Datastores: 

![VMware Data Collection](https://pub-4dac79d0e98d4b6eaa378b38fc71cbf8.r2.dev/autok8s-vmware-readme02.png)

Creating and applying tags for the CPI driver, plus the removal of previous tags:

![VMware Data Collection](https://pub-4dac79d0e98d4b6eaa378b38fc71cbf8.r2.dev/autok8s-vmware-readme03.png)

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
