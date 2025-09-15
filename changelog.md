
### 1.6.0
*September 16th 2025*

- Fix k8s version parameter to allow build version (1.23.45)
- Only grab latest version from GitHub when `$k8sVersion` is `latest`

---
### 1.6.0
*September 14th 2025*

- Add support for Flux CD !
- Update documentation: wording, formatting, spelling mistakes and references.

---
### 1.5.0
*September 9th 2025*

- Includes an option to set the pod network and service CIDRs
- Includes option to provide a cluster name (triggers the creation of a config file for `kubeadm init`)

---
### 1.4.1
*September 6th 2025*

- Control-Plane taint toleration added to Hubble regardless of `--k8s-allow-master-node-schedule` parameter
- Control-Plane taint toleration added to MetalLB
- Control-Plane taint toleration added to Metrics server
- Adds 5 min wait to each apt-get command in case anther process is locking `/var/lib/dpkg/lock-frontend`

---
### 1.4.0
*September 5th 2025*

- Include option to provide kubeadm config file instead
- Add validation around new `--k8skubeadm-config` param
- Fix bug in which setting NFS default to true meant having two default storage classes

---
### 1.3.0
*April 26th 2025*

- Add installation of Metrics Server

---
### 1.2.0
*March 26th 2025*

- Add feature for installing Cilium CNI.
- Refactor control-plane node taint removal steps.
- Add 10 second sleep after any warning message.
- Fun improvements to splash screen.
- Hide output of `apt-get update`.

Tested with:

- Ubuntu Server 24.04
- Kubernetes Version 1.32.3

---
### 1.1.0
*March 24th 2025*

- Add feature for choosing CNI.

Tested with:

- Ubuntu Server 24.04
- Kubernetes Version 1.32.3

---
### 1.0.1
*March 23th 2025*

- Use community package repository (pkgs.k8s.io). (Google ones are dead)
- Use GitHub to determine latest version (required due to the above).
- Add validation for `--k8s-version` parameter.
- Reorder steps, placing prerequisite config between package install and `kubeadm [init|join]`. Also place splash and sudo checks at top of script.
- Add script version to banner.
- Change CIDR generator code so it doesn't break syntax highlighting.
- Added `--k8s-kubeadm-options` parameter.
- Added `set -euo pipefail` to terminate script on failure.
- Update documentation.
- Added 1 second sleep before `apt-get update` due to observed file locks / race conditions.
- Added changelog.md.

Tested with:

- Ubuntu Server 24.04
- Kubernetes Version 1.32.3
