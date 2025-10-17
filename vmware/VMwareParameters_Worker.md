# VMware Worker Parameters
The following is a list of all available parameters you can use with the `vmware_setup_worker_node.sh` script. Below are some examples to help you get started and notes on things to watch for when setting certain parameter values.

Parameter values wrapped in quotes must include the quotes when used.
<br>
<br>

|Parameter Name|Description|Default Value|Example Value|Required|
|---|---|---|---|---|
|`--vcenter-host`|The hostname or IP address of the vCenter server.|-|`vcenter.contoso.net`|Yes|
|`--vcenter-username`|Username used to authenticate with vCenter.|`administrator@vsphere.local`|`kube@vsphere.local`|No|
|`--vcenter-password`|Password for the specified vCenter user.|-|`password123!`|Yes|
|`--vcenter-insecure`|Set to `true` to skip SSL certificate verification.|`false`|`true`|No|
|`--vcenter-user-group`|Group name used to verify vCenter permissions.|`Administrators`|`CloudAdmins`|No|
|`--manage-tags-for-vsphere-cpi`|Set to `false` to disable management of VM tags.|`true`|`false`|No|
|`--vsphere-cpi-tag-category-region`|Name of the vSphere tag category representing the Kubernetes region.|`k8s-region`|`region`|No|
|`--vsphere-cpi-tag-category-zone`|Name of the vSphere tag category representing the Kubernetes zone.|`k8s-zone`|`zone`|No|
|`--vsphere-cpi-tag-region`|Specific tag value within the region category to apply.|-|`uk-south`|No|
|`--vsphere-cpi-tag-zone`|Specific tag value within the zone category to apply.|-|`cluster-a`|No|
|`--vsphere-cpi-create-tags`|Set to `false` to disable creation of tags and tag categories when missing.|`true`|`false`|No|
|`--continue-on-hardware-error`|Set to `true` to continue execution even if hardware validation fails.|`false`|`true`|No|

## Notes

The worker script is not required to successfully deploy the CSI or CPI drivers to the cluster; its purpose is to check and configure VMs with the correct settings and tags if they are not already configured. If your VMs already meet the requirements, you can skip this script.

This script cannot apply the taint to the VM it is running on. If you run this script retrospectively on a VM where the `--k8s-cloud-provider` parameter was not used, run it on each worker node before running the VMware master node script, which will taint all nodes at the end.

If you need to manually taint a node you can do so with this command:

```bash
kubectl taint <node_name> node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule
```

### VMware Tags & K8s Labels

The script ensures that the requested tags are applied. If the requested tag and/or tag categories do not exist in VMware, they will be created. If different tags belonging to the same tag category are present, those tags will be removed before creating and adding the requested ones. You can disable tag creation with the `--vsphere-cpi-create-tags false` parameter.

If you do not specify a value for `--vsphere-cpi-tag-region` or `--vsphere-cpi-tag-zone`, the script will not be able to assign tags and will only check for the presence of tags that belong to the specified tag categories (`k8s-region` and `k8s-zone` by default). This is not an issue if you manage tags through another process, such as Terraform.

> [!CAUTION]
>
> If no tags exist on the VM(s) in the categories defined in the `labels` section of the vSphere ConfigMap `cloud-config` (see below), the CPI driver cannot complete node initialization and the node will remain tainted.
>
> For example, if you specify the tag category `k8s-zone`, VMs **must** have a tag belonging to this category for successful initialization.

## Parameter Examples

<br>

Example Usage — Minimum Required:

```bash
./vmware_setup_worker_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-password password123
```
<br>

Example Usage — Common:

```bash
./vmware_setup_worker_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-username kubeadmin@vsphere.local \
    --vcenter-password password123 \
    --vcenter-user-group ServiceAccounts \
    --vcenter-insecure true \
    --vsphere-cpi-tag-region UK \
    --vsphere-cpi-tag-zone south
```

<br>

Example Usage — All:

```bash
./vmware_setup_worker_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-username kubeadmin@vsphere.local \
    --vcenter-password password123 \
    --vcenter-user-group ServiceAccounts \
    --vcenter-insecure true \
    --manage-tags-for-vsphere-cpi true \
    --vsphere-cpi-tag-category-region region \
    --vsphere-cpi-tag-category-zone zone \
    --vsphere-cpi-tag-region UK \
    --vsphere-cpi-tag-zone south \
    --vsphere-cpi-create-tags true \
    --continue-on-hardware-error true
```