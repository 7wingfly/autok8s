# VMware Master Parameters
The following is a list of all available parameters you can use with the `vmware_setup_master_node.sh` script. Below that are some examples that can help you get started and some notes on things to watch out for when setting some of the parameter values. 

Parameter values which are wrapped in quotes must include the quotes when applied.
<br>
<br>

|Parameter Name|Description|Default Value|Example Value|Required|
|---|---|---|---|---|
|`--vcenter-host`|The hostname or IP address of the vCenter server.|-|`vcenter.contoso.net`|Yes|
|`--vcenter-username`|Username used to authenticate with vCenter.|`administrator@vsphere.local`|`kube@vsphere.local`|No|
|`--vcenter-password`|Password for the specified vCenter user.|-|`password123!`|Yes|
|`--vcenter-insecure`|Set to `true` to skip SSL certificate verification.|`false`|`true`|No|
|`--vcenter-user-group`|Group name used to verify vCenter permissions.|`Administrators`|`CloudAdmins`|No|
|`--vcenter-datacenter`|Name of the vSphere Datacenter containing the cluster.|`Datacenter`|`London-DC01`|No|
|`--vcenter-datastores`|List of datastores to register for CSI.|-|`"datastore1,datastore2"`|No|
|`--vcenter-datastores-delimiter`|Delimiter used to separate datastore names.|`,`|`;`|No|
|`--vsphere-csi-driver-version`|Version of the VMware vSphere CSI driver to install. Use `latest` for automatic detection.|`latest`|`3.2.0`|No|
|`--storage-class-name-prefix`|Prefix for generated StorageClass names.|`vsphere-csi`|`vsphere-prod`|No|
|`--install-vsphere-cpi-driver`|Set to `false` to skip installation of the VMware CPI driver.|`true`|`false`|No|
|`--vsphere-cpi-tag-category-region`|Name of the vSphere tag category representing the Kubernetes region.|`k8s-region`|`region`|No|
|`--vsphere-cpi-tag-category-zone`|Name of the vSphere tag category representing the Kubernetes zone.|`k8s-zone`|`zone`|No|
|`--vsphere-cpi-tag-region`|Specific tag value within the region category to apply.|-|`uk-south`|No|
|`--vsphere-cpi-tag-zone`|Specific tag value within the zone category to apply.|-|`cluster-a`|No|
|`--vsphere-cpi-create-tags`|Set to `false` to disable the creation of tags and tag categories when missing.|`true`|`false`|No|
|`--vsphere-cpi-config`|Path to an existing vSphere CPI config YAML file. If omitted, one is generated.|-|`/path/to/vsphere.conf`|No|
|`--continue-on-hardware-error`|Set to `true` to continue execution even if hardware validation fails.|`false`|`true`|No|

## Notes

### VMware Datastores & K8s Storage Classes

The script will install the CSI driver, and then automatically create two Storage Classes for each datastore found in the specified Datacenter, one with a `delete` retention policy and another with `retain`. If you want to specify the datastore(s) for which Storage Classes should be created, you can do so with the `--vcenter-datastores` parameter which takes a comma separate list of datastore names.

The Storage Class names are generated automatically in the format `<prefix>-<datastore_name>-<retention_policy>`. The prefix can be set via the `--storage-class-name-prefix` parameter and has a default value of `vsphere-csi`. If a datastore name contains characters not supported by Kubernetes it will be sanitized before creation.

For example a datastore named `SAN Datastore1` will result in the following Storage Classes
```
vsphere-csi-san-datastore1-retain
vsphere-csi-san-datastore1-delete
```

### VMware Tags & K8s Labels

The script will ensure that the requested tags are always applied. If the requested tag and/or tag categories do not exist in VMware, they will be created. If different tags belonging to the same tag category are present, these will be removed before creating and adding the requested ones. You can disable tag creation with the `--vsphere-cpi-create-tags false` parameter.

If you do not specify a value for `--vsphere-cpi-tag-region` or `--vsphere-cpi-tag-zone`, the script will not be able to assign tags and will only check for the presence of tags which belong to the specified tag categories (`k8s-region` and `k8s-zone` by default). This is not an issue if you are managing tags through some other process such as Terraform.

> [!CAUTION]
>
> If there are no tags on the VM(s) belonging to categories defined in the `labels` section of the vSphere ConfigMap `cloud-config` (see more below), the CPI driver will be unable to complete the initialization of the node and it will remain tainted. 
>
> For example, if you specify the tag category `k8s-zone`, VMs **must** have a tag belonging to this category for successful initialization.

## Parameter Examples

<br>

Example Usage - Minimum Required:

```bash
./vmware_setup_master_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-password password123
```
<br>

Example Usage - VMware CSI Driver only:

```bash
./vmware_setup_master_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-username kubeadmin@vsphere.local \
    --vcenter-password password123 \
    --vcenter-user-group ServiceAccounts \
    --vcenter-insecure true \
    --vcenter-datacenter Datacenter1 \
    --vcenter-datastores "SAN Datastore1, Host1 Datastore" \
    --install-vsphere-cpi-driver false
```

<br>

Example Usage - VMware CSI & CPI Drivers:

```bash
./vmware_setup_master_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-username kubeadmin@vsphere.local \
    --vcenter-password password123 \
    --vcenter-user-group ServiceAccounts \
    --vcenter-insecure true \
    --vcenter-datacenter Datacenter1 \
    --vcenter-datastores "SAN Datastore1, Host1 Datastore" \
    --vsphere-cpi-tag-category-region region \
    --vsphere-cpi-tag-category-zone zone \
    --vsphere-cpi-tag-region UK \
    --vsphere-cpi-tag-zone west
```

<br>

Example Usage - Custom CPI config file:

You may want to provide your own `vsphere.conf` file instead of allowing the script to generate one for you. If you do this you will need to supply all of the values including the tags, which will not be checked during setup. 

You will need to reference a secret containing vCenter credentials, to use the one generated by the script, use secret name `vsphere-cloud-secret` and namespace `vmware-system-cpi`. The config file will be stored in a ConfigMap called `cloud-config` also in the `vmware-system-cpi` namespace.

Below is an example `vsphere.conf` config file:

```yaml
global:
  port: 443
  insecureFlag: true
  secretName: vsphere-cloud-secret
  secretNamespace: vmware-system-cpi
vcenter:
  vcenter.contoso.net:
    server: vcenter.contoso.net
    datacenters:
      - Datacenter1
labels:
  region: k8s-region
  zone: k8s-zone
```

Reference the file when running the script:

```bash
./vmware_setup_master_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-username kubeadmin@vsphere.local \
    --vcenter-password password123 \
    --vcenter-user-group ServiceAccounts \
    --vcenter-insecure true \
    --vcenter-datacenter Datacenter1 \
    --vsphere-cpi-config ~/vsphere.conf
```
<br>

> [!TIP]
>
> The config file can be written as either YAML or INI interchangeably, however the examples given in the official documentation are written in INI. See: https://cloud-provider-vsphere.sigs.k8s.io/cloud_config

<br>

Example Usage - All:

```bash
./vmware_setup_master_node.sh \
    --vcenter-host vcenter.contoso.net \
    --vcenter-username kubeadmin@vsphere.local \
    --vcenter-password password123 \
    --vcenter-user-group ServiceAccounts \
    --vcenter-insecure true \
    --vcenter-datacenter Datacenter1 \
    --vcenter-datastores "SAN Datastore1;Host1 Datastore" \
    --vcenter-datastores-delimiter ";" \
    --vsphere-csi-driver-version 3.5.0 \
    --vsphere-cpi-tag-category-region region \
    --vsphere-cpi-tag-category-zone zone \
    --vsphere-cpi-tag-region UK \
    --vsphere-cpi-tag-zone west \
    --vsphere-cpi-create-tags true \
    --continue-on-hardware-error true
```